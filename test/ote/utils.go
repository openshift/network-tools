package ote

import (
	"context"
	"encoding/json"
	"fmt"
	"os/exec"
	"strings"
	"time"

	g "github.com/onsi/ginkgo/v2"

	corev1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/apis/meta/v1/unstructured"
	"k8s.io/apimachinery/pkg/runtime/schema"
	"k8s.io/apimachinery/pkg/types"
	"k8s.io/apimachinery/pkg/util/wait"
	"k8s.io/client-go/dynamic"
	"k8s.io/client-go/kubernetes"
	"k8s.io/client-go/tools/clientcmd"
)

const (
	helloSDNImage = "quay.io/openshifttest/hello-sdn@sha256:c89445416459e7adea9a5a416b3365ed3d74f2491beb904d61dc8d1eb89a72a4"
	networkToolsImageStream = "openshift/network-tools:latest"
)

func getKubeClientAndConfig() (*kubernetes.Clientset, *dynamic.DynamicClient, error) {
	loadingRules := clientcmd.NewDefaultClientConfigLoadingRules()
	configOverrides := &clientcmd.ConfigOverrides{}
	kubeConfig := clientcmd.NewNonInteractiveDeferredLoadingClientConfig(loadingRules, configOverrides)

	config, err := kubeConfig.ClientConfig()
	if err != nil {
		return nil, nil, fmt.Errorf("failed to load kubeconfig: %w", err)
	}

	clientset, err := kubernetes.NewForConfig(config)
	if err != nil {
		return nil, nil, fmt.Errorf("failed to create kubernetes clientset: %w", err)
	}

	dynClient, err := dynamic.NewForConfig(config)
	if err != nil {
		return nil, nil, fmt.Errorf("failed to create dynamic client: %w", err)
	}

	return clientset, dynClient, nil
}

func checkNetworkType(ctx context.Context, dynClient *dynamic.DynamicClient) string {
	gvr := schema.GroupVersionResource{
		Group:    "operator.openshift.io",
		Version:  "v1",
		Resource: "networks",
	}
	obj, err := dynClient.Resource(gvr).Get(ctx, "cluster", metav1.GetOptions{})
	if err != nil {
		fmt.Fprintf(g.GinkgoWriter, "Failed to get network operator: %v\n", err)
		return ""
	}
	networkType, found, err := unstructured.NestedString(obj.Object, "spec", "defaultNetwork", "type")
	if err != nil || !found {
		return ""
	}
	return strings.ToLower(networkType)
}

func createNamespace(ctx context.Context, clientset *kubernetes.Clientset, name string) error {
	ns := &corev1.Namespace{
		ObjectMeta: metav1.ObjectMeta{
			Name: name,
		},
	}
	_, err := clientset.CoreV1().Namespaces().Create(ctx, ns, metav1.CreateOptions{})
	return err
}

func deleteNamespace(ctx context.Context, clientset *kubernetes.Clientset, name string) error {
	return clientset.CoreV1().Namespaces().Delete(ctx, name, metav1.DeleteOptions{})
}

func setNamespacePrivileged(ctx context.Context, clientset *kubernetes.Clientset, ns string) error {
	patch := map[string]interface{}{
		"metadata": map[string]interface{}{
			"labels": map[string]string{
				"pod-security.kubernetes.io/enforce": "privileged",
				"pod-security.kubernetes.io/audit":   "privileged",
				"pod-security.kubernetes.io/warn":    "privileged",
			},
		},
	}
	patchBytes, err := json.Marshal(patch)
	if err != nil {
		return err
	}
	_, err = clientset.CoreV1().Namespaces().Patch(ctx, ns, types.MergePatchType, patchBytes, metav1.PatchOptions{})
	return err
}

func createPod(ctx context.Context, clientset *kubernetes.Clientset, ns, name string) error {
	pod := &corev1.Pod{
		ObjectMeta: metav1.ObjectMeta{
			Name:      name,
			Namespace: ns,
			Labels: map[string]string{
				"name": "hello-pod",
			},
		},
		Spec: corev1.PodSpec{
			SecurityContext: &corev1.PodSecurityContext{
				RunAsNonRoot: boolPtr(true),
				SeccompProfile: &corev1.SeccompProfile{
					Type: corev1.SeccompProfileTypeRuntimeDefault,
				},
			},
			Containers: []corev1.Container{
				{
					Name:  "hello-pod",
					Image: helloSDNImage,
					SecurityContext: &corev1.SecurityContext{
						AllowPrivilegeEscalation: boolPtr(false),
						Capabilities: &corev1.Capabilities{
							Drop: []corev1.Capability{"ALL"},
						},
					},
				},
			},
		},
	}
	_, err := clientset.CoreV1().Pods(ns).Create(ctx, pod, metav1.CreateOptions{})
	return err
}

func createPodOnNode(ctx context.Context, clientset *kubernetes.Clientset, ns, name, nodeName string) error {
	pod := &corev1.Pod{
		ObjectMeta: metav1.ObjectMeta{
			Name:      name,
			Namespace: ns,
			Labels: map[string]string{
				"name": "hello-pod",
			},
		},
		Spec: corev1.PodSpec{
			NodeName: nodeName,
			SecurityContext: &corev1.PodSecurityContext{
				RunAsNonRoot: boolPtr(true),
				SeccompProfile: &corev1.SeccompProfile{
					Type: corev1.SeccompProfileTypeRuntimeDefault,
				},
			},
			Containers: []corev1.Container{
				{
					Name:  "hello-pod",
					Image: helloSDNImage,
					SecurityContext: &corev1.SecurityContext{
						AllowPrivilegeEscalation: boolPtr(false),
						Capabilities: &corev1.Capabilities{
							Drop: []corev1.Capability{"ALL"},
						},
					},
				},
			},
		},
	}
	_, err := clientset.CoreV1().Pods(ns).Create(ctx, pod, metav1.CreateOptions{})
	return err
}

func createHostNetworkPodOnNode(ctx context.Context, clientset *kubernetes.Clientset, ns, name, nodeName string) error {
	pod := &corev1.Pod{
		ObjectMeta: metav1.ObjectMeta{
			Name:      name,
			Namespace: ns,
			Labels: map[string]string{
				"name": "hello-pod",
			},
		},
		Spec: corev1.PodSpec{
			NodeName:    nodeName,
			HostNetwork: true,
			SecurityContext: &corev1.PodSecurityContext{
				RunAsNonRoot: boolPtr(false),
				SeccompProfile: &corev1.SeccompProfile{
					Type: corev1.SeccompProfileTypeRuntimeDefault,
				},
			},
			Containers: []corev1.Container{
				{
					Name:  "hello-pod",
					Image: helloSDNImage,
					SecurityContext: &corev1.SecurityContext{
						AllowPrivilegeEscalation: boolPtr(false),
						Capabilities: &corev1.Capabilities{
							Drop: []corev1.Capability{"ALL"},
						},
					},
				},
			},
		},
	}
	_, err := clientset.CoreV1().Pods(ns).Create(ctx, pod, metav1.CreateOptions{})
	return err
}

func waitPodReady(ctx context.Context, clientset *kubernetes.Clientset, ns, name string) error {
	return wait.PollUntilContextTimeout(ctx, 5*time.Second, 60*time.Second, true, func(ctx context.Context) (bool, error) {
		pod, err := clientset.CoreV1().Pods(ns).Get(ctx, name, metav1.GetOptions{})
		if err != nil {
			fmt.Fprintf(g.GinkgoWriter, "Error getting pod %s: %v, retrying...\n", name, err)
			return false, nil
		}
		switch pod.Status.Phase {
		case corev1.PodRunning, corev1.PodSucceeded:
			return true, nil
		case corev1.PodFailed:
			return false, fmt.Errorf("pod %s failed", name)
		default:
			fmt.Fprintf(g.GinkgoWriter, "Pod %s phase: %s, waiting...\n", name, pod.Status.Phase)
			return false, nil
		}
	})
}

func getPodIP(ctx context.Context, clientset *kubernetes.Clientset, ns, name string) (string, error) {
	pod, err := clientset.CoreV1().Pods(ns).Get(ctx, name, metav1.GetOptions{})
	if err != nil {
		return "", err
	}
	if len(pod.Status.PodIPs) == 0 {
		return "", fmt.Errorf("pod %s has no IPs", name)
	}
	return pod.Status.PodIPs[0].IP, nil
}

func getPodNodeName(ctx context.Context, clientset *kubernetes.Clientset, ns, name string) (string, error) {
	pod, err := clientset.CoreV1().Pods(ns).Get(ctx, name, metav1.GetOptions{})
	if err != nil {
		return "", err
	}
	return pod.Spec.NodeName, nil
}

func getPodsWithLabel(ctx context.Context, clientset *kubernetes.Clientset, ns, label string) ([]string, error) {
	pods, err := clientset.CoreV1().Pods(ns).List(ctx, metav1.ListOptions{LabelSelector: label})
	if err != nil {
		return nil, err
	}
	var names []string
	for _, p := range pods.Items {
		names = append(names, p.Name)
	}
	return names, nil
}

func getOVNKMasterPod(ctx context.Context, clientset *kubernetes.Clientset) (string, error) {
	lease, err := clientset.CoordinationV1().Leases("openshift-ovn-kubernetes").Get(ctx, "ovn-kubernetes-master", metav1.GetOptions{})
	if err != nil {
		return "", err
	}
	if lease.Spec.HolderIdentity == nil {
		return "", fmt.Errorf("ovn-kubernetes-master lease has no holder")
	}
	return *lease.Spec.HolderIdentity, nil
}

func collectMustGather(destDir, imageStream string, params []string) (string, error) {
	args := []string{"adm", "must-gather"}
	if destDir != "" {
		args = append(args, "--dest-dir="+destDir)
	}
	if imageStream != "" {
		args = append(args, "--image-stream="+imageStream)
	}
	if len(params) > 0 {
		args = append(args, "--")
		args = append(args, params...)
	}
	fmt.Fprintf(g.GinkgoWriter, "Running: oc %s\n", strings.Join(args, " "))
	output, err := exec.Command("oc", args...).CombinedOutput()
	if err != nil && strings.Contains(string(output), "ImagePullBackOff") {
		fmt.Fprintf(g.GinkgoWriter, "Image pull failed, retrying...\n")
		output, err = exec.Command("oc", args...).CombinedOutput()
	}
	if err != nil {
		fmt.Fprintf(g.GinkgoWriter, "collectMustGather failed: %v, output: %s\n", err, string(output))
		return string(output), err
	}
	return string(output), nil
}

func getReadySchedulableNodes(ctx context.Context, clientset *kubernetes.Clientset) (*corev1.NodeList, error) {
	nodes, err := clientset.CoreV1().Nodes().List(ctx, metav1.ListOptions{})
	if err != nil {
		return nil, err
	}
	var filtered []corev1.Node
	for _, node := range nodes.Items {
		if node.Spec.Unschedulable {
			continue
		}
		ready := false
		for _, cond := range node.Status.Conditions {
			if cond.Type == corev1.NodeReady && cond.Status == corev1.ConditionTrue {
				ready = true
				break
			}
		}
		if ready {
			filtered = append(filtered, node)
		}
	}
	return &corev1.NodeList{Items: filtered}, nil
}

func boolPtr(b bool) *bool {
	return &b
}
