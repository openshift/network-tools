package ote

import (
	"context"
	"os"
	"strings"
	"time"

	g "github.com/onsi/ginkgo/v2"
	o "github.com/onsi/gomega"

	"k8s.io/client-go/dynamic"
	"k8s.io/client-go/kubernetes"
	netutils "k8s.io/utils/net"
)

var _ = g.Describe("[sig-networking][Suite:openshift/network-tools] SDN network-tools", func() {
	var (
		clientset *kubernetes.Clientset
		dynClient *dynamic.DynamicClient
		ctx       context.Context
		cancel    context.CancelFunc

		expPod2PodResult = []string{
			"ovn-trace source pod to destination pod indicates success",
			"ovn-trace destination pod to source pod indicates success",
			"ovs-appctl ofproto/trace source pod to destination pod indicates success",
			"ovs-appctl ofproto/trace destination pod to source pod indicates success",
			"ovn-detrace source pod to destination pod indicates success",
			"ovn-detrace destination pod to source pod indicates success",
		}
		expPod2PodRemoteResult = []string{
			"ovn-trace (remote) source pod to destination pod indicates success",
			"ovn-trace (remote) destination pod to source pod indicates success",
		}
		expPod2SvcResult = []string{
			"ovn-trace source pod to service clusterIP indicates success",
		}
	)

	g.BeforeEach(func() {
		ctx, cancel = context.WithTimeout(context.Background(), 30*time.Minute)

		var err error
		clientset, dynClient, err = getKubeClientAndConfig()
		o.Expect(err).NotTo(o.HaveOccurred())

		networkType := checkNetworkType(ctx, dynClient)
		if !strings.Contains(networkType, "ovn") {
			g.Skip("Skip testing on non-ovn cluster")
		}
	})

	g.AfterEach(func() {
		cancel()
	})

	g.It("[JIRA:Networking][OTP] 67625-67648-Check ovnkube-trace pod2pod and pod2hostnetworkpod traffic", func() {
		nodeList, err := getReadySchedulableNodes(ctx, clientset)
		o.Expect(err).NotTo(o.HaveOccurred())
		if len(nodeList.Items) < 2 {
			g.Skip("Not enough nodes available, need at least 2")
		}
		workerNode1 := nodeList.Items[0].Name
		workerNode2 := nodeList.Items[1].Name
		tmpPath := "/tmp/ocp-67625-67648"
		defer os.RemoveAll(tmpPath)

		ns := "network-tools-67625-" + strings.ToLower(string(time.Now().Format("150405")))
		err = createNamespace(ctx, clientset, ns)
		o.Expect(err).NotTo(o.HaveOccurred())
		defer deleteNamespace(ctx, clientset, ns)

		g.By("Set namespace as privileged for hostnetworked pods")
		err = setNamespacePrivileged(ctx, clientset, ns)
		o.Expect(err).NotTo(o.HaveOccurred())

		g.By("1. Create hello-pod1, pod located on the first node")
		err = createPodOnNode(ctx, clientset, ns, "hello-pod1", workerNode1)
		o.Expect(err).NotTo(o.HaveOccurred())
		err = waitPodReady(ctx, clientset, ns, "hello-pod1")
		o.Expect(err).NotTo(o.HaveOccurred())

		g.By("2. Create hello-pod2 and hostnetwork-hello-pod2, pod located on the first node")
		err = createPodOnNode(ctx, clientset, ns, "hello-pod2", workerNode1)
		o.Expect(err).NotTo(o.HaveOccurred())
		err = waitPodReady(ctx, clientset, ns, "hello-pod2")
		o.Expect(err).NotTo(o.HaveOccurred())
		err = createHostNetworkPodOnNode(ctx, clientset, ns, "hostnetwork-hello-pod2", workerNode1)
		o.Expect(err).NotTo(o.HaveOccurred())
		err = waitPodReady(ctx, clientset, ns, "hostnetwork-hello-pod2")
		o.Expect(err).NotTo(o.HaveOccurred())

		g.By("3. Create hello-pod3 and hostnetwork-hello-pod3, pod located on the second node")
		err = createPodOnNode(ctx, clientset, ns, "hello-pod3", workerNode2)
		o.Expect(err).NotTo(o.HaveOccurred())
		err = waitPodReady(ctx, clientset, ns, "hello-pod3")
		o.Expect(err).NotTo(o.HaveOccurred())
		err = createHostNetworkPodOnNode(ctx, clientset, ns, "hostnetwork-hello-pod3", workerNode2)
		o.Expect(err).NotTo(o.HaveOccurred())
		err = waitPodReady(ctx, clientset, ns, "hostnetwork-hello-pod3")
		o.Expect(err).NotTo(o.HaveOccurred())

		g.By("4. Simulate traffic between pod and pod when they land on the same node")
		podIP1, err := getPodIP(ctx, clientset, ns, "hello-pod1")
		o.Expect(err).NotTo(o.HaveOccurred())
		addrFamily := "ip4"
		if netutils.IsIPv6String(podIP1) {
			addrFamily = "ip6"
		}
		cmd := "ovnkube-trace -src-namespace " + ns + " -src hello-pod1 -dst-namespace " + ns + " -dst hello-pod2 -tcp -addr-family " + addrFamily
		traceOutput, cmdErr := collectMustGather(tmpPath, networkToolsImageStream, []string{cmd})
		o.Expect(cmdErr).NotTo(o.HaveOccurred())
		for _, expResult := range expPod2PodResult {
			o.Expect(traceOutput).To(o.ContainSubstring(expResult))
		}

		g.By("5. Simulate traffic between pod and pod when they land on different nodes")
		cmd = "ovnkube-trace -src-namespace " + ns + " -src hello-pod1 -dst-namespace " + ns + " -dst hello-pod3 -tcp -addr-family " + addrFamily
		traceOutput, cmdErr = collectMustGather(tmpPath, networkToolsImageStream, []string{cmd})
		o.Expect(cmdErr).NotTo(o.HaveOccurred())
		for _, expResult := range expPod2PodResult {
			o.Expect(traceOutput).To(o.ContainSubstring(expResult))
		}
		for _, expResult := range expPod2PodRemoteResult {
			o.Expect(traceOutput).To(o.ContainSubstring(expResult))
		}

		g.By("6. Simulate traffic between pod and hostnetwork pod when they land on the same node")
		cmd = "ovnkube-trace -src-namespace " + ns + " -src hello-pod1 -dst-namespace " + ns + " -dst hostnetwork-hello-pod2 -udp -addr-family " + addrFamily
		traceOutput, cmdErr = collectMustGather(tmpPath, networkToolsImageStream, []string{cmd})
		o.Expect(cmdErr).NotTo(o.HaveOccurred())
		for _, expResult := range expPod2PodResult {
			o.Expect(traceOutput).To(o.ContainSubstring(expResult))
		}

		g.By("7. Simulate traffic between pod and hostnetwork pod when they land on different nodes")
		cmd = "ovnkube-trace -src-namespace " + ns + " -src hello-pod1 -dst-namespace " + ns + " -dst hostnetwork-hello-pod3 -udp -addr-family " + addrFamily
		traceOutput, cmdErr = collectMustGather(tmpPath, networkToolsImageStream, []string{cmd})
		o.Expect(cmdErr).NotTo(o.HaveOccurred())
		for _, expResult := range expPod2PodResult {
			o.Expect(traceOutput).To(o.ContainSubstring(expResult))
		}
		o.Expect(traceOutput).To(o.ContainSubstring(expPod2PodRemoteResult[1]))
	})

	g.It("[JIRA:Networking][OTP] 67649-Check ovnkube-trace pod2service traffic", func() {
		nodeList, err := getReadySchedulableNodes(ctx, clientset)
		o.Expect(err).NotTo(o.HaveOccurred())
		if len(nodeList.Items) < 1 {
			g.Skip("Not enough nodes available for the test")
		}
		tmpPath := "/tmp/ocp-67649"
		defer os.RemoveAll(tmpPath)

		ns := "network-tools-67649-" + strings.ToLower(string(time.Now().Format("150405")))
		err = createNamespace(ctx, clientset, ns)
		o.Expect(err).NotTo(o.HaveOccurred())
		defer deleteNamespace(ctx, clientset, ns)

		g.By("1. Create hello-pod")
		err = createPod(ctx, clientset, ns, "hello-pod")
		o.Expect(err).NotTo(o.HaveOccurred())
		err = waitPodReady(ctx, clientset, ns, "hello-pod")
		o.Expect(err).NotTo(o.HaveOccurred())

		g.By("2. Simulate traffic between pod and service")
		podIP, err := getPodIP(ctx, clientset, ns, "hello-pod")
		o.Expect(err).NotTo(o.HaveOccurred())
		addrFamily := "ip4"
		if netutils.IsIPv6String(podIP) {
			addrFamily = "ip6"
		}
		cmd := "ovnkube-trace -src-namespace " + ns + " -src hello-pod -dst-namespace openshift-dns -service dns-default -tcp -addr-family " + addrFamily
		traceOutput, cmdErr := collectMustGather(tmpPath, networkToolsImageStream, []string{cmd})
		o.Expect(cmdErr).NotTo(o.HaveOccurred())
		for _, expResult := range expPod2SvcResult {
			o.Expect(traceOutput).To(o.ContainSubstring(expResult))
		}
	})
})

var _ = g.Describe("[sig-networking][Suite:openshift/network-tools] SDN network-tools", func() {
	var (
		clientset *kubernetes.Clientset
		dynClient *dynamic.DynamicClient
		ctx       context.Context
		cancel    context.CancelFunc
	)

	g.BeforeEach(func() {
		ctx, cancel = context.WithTimeout(context.Background(), 30*time.Minute)

		var err error
		clientset, dynClient, err = getKubeClientAndConfig()
		o.Expect(err).NotTo(o.HaveOccurred())
	})

	g.AfterEach(func() {
		cancel()
	})

	g.It("[JIRA:Networking][OTP] 55889-Verify ovn-db-run-command", func() {
		networkType := checkNetworkType(ctx, dynClient)
		if !strings.Contains(networkType, "ovn") {
			g.Skip("Skip testing on non-ovn cluster")
		}

		g.By("1. Run ovn-nbctl command with ovn-db-run-command script")
		mustgatherDir := "/tmp/must-gather-55889-1"
		defer os.RemoveAll(mustgatherDir)
		output, cmdErr := collectMustGather(mustgatherDir, networkToolsImageStream, []string{"network-tools", "ovn-db-run-command", "ovn-nbctl", "lr-list"})
		o.Expect(cmdErr).NotTo(o.HaveOccurred())
		o.Expect(output).To(o.ContainSubstring("ovn_cluster_router"))

		g.By("2. Run ovn-sbctl command with ovn-db-run-command script")
		mustgatherDir = "/tmp/must-gather-55889-2"
		defer os.RemoveAll(mustgatherDir)
		output, cmdErr = collectMustGather(mustgatherDir, networkToolsImageStream, []string{"network-tools", "ovn-db-run-command", "ovn-sbctl", "show"})
		o.Expect(cmdErr).NotTo(o.HaveOccurred())
		o.Expect(output).To(o.ContainSubstring("Port_Binding"))

		g.By("3. Run ovndb command in specified pod with ovn-db-run-command script")
		ovnNodePods, err := getPodsWithLabel(ctx, clientset, "openshift-ovn-kubernetes", "app=ovnkube-node")
		o.Expect(err).NotTo(o.HaveOccurred())
		o.Expect(len(ovnNodePods)).NotTo(o.BeZero())

		nodeName, err := getPodNodeName(ctx, clientset, "openshift-ovn-kubernetes", ovnNodePods[0])
		o.Expect(err).NotTo(o.HaveOccurred())

		mustgatherDir = "/tmp/must-gather-55889-3"
		defer os.RemoveAll(mustgatherDir)
		output, cmdErr = collectMustGather(mustgatherDir, networkToolsImageStream, []string{"network-tools", "ovn-db-run-command", "-p", ovnNodePods[0], "ovn-nbctl", "lr-list"})
		o.Expect(cmdErr).NotTo(o.HaveOccurred())
		o.Expect(output).To(o.ContainSubstring("GR_" + nodeName))
	})

	g.It("[JIRA:Networking][OTP] 55887-Verify pod-run-netns-command", func() {
		nodeList, err := getReadySchedulableNodes(ctx, clientset)
		o.Expect(err).NotTo(o.HaveOccurred())
		if len(nodeList.Items) < 1 {
			g.Skip("Not enough nodes available for the test")
		}

		ns := "network-tools-55887-" + strings.ToLower(string(time.Now().Format("150405")))
		err = createNamespace(ctx, clientset, ns)
		o.Expect(err).NotTo(o.HaveOccurred())
		defer deleteNamespace(ctx, clientset, ns)

		g.By("0. Create hello-pod")
		err = createPod(ctx, clientset, ns, "hello-pod")
		o.Expect(err).NotTo(o.HaveOccurred())
		err = waitPodReady(ctx, clientset, ns, "hello-pod")
		o.Expect(err).NotTo(o.HaveOccurred())
		podIP, err := getPodIP(ctx, clientset, ns, "hello-pod")
		o.Expect(err).NotTo(o.HaveOccurred())

		g.By("1. Run multiple commands with pod-run-netns-command script")
		mustgatherDir := "/tmp/must-gather-55887-1"
		defer os.RemoveAll(mustgatherDir)
		output, cmdErr := collectMustGather(mustgatherDir, networkToolsImageStream, []string{"network-tools", "pod-run-netns-command", "--multiple-commands", ns, "hello-pod", "ip a show eth0; ip a show lo"})
		o.Expect(cmdErr).NotTo(o.HaveOccurred())
		o.Expect(output).To(o.ContainSubstring(podIP))
		o.Expect(output).To(o.ContainSubstring("127.0.0.1"))

		g.By("2. Run command with no-substitution flag with pod-run-netns-command script")
		mustgatherDir = "/tmp/must-gather-55887-2"
		defer os.RemoveAll(mustgatherDir)
		output, cmdErr = collectMustGather(mustgatherDir, networkToolsImageStream, []string{"network-tools", "pod-run-netns-command", "--no-substitution", ns, "hello-pod", "'i=0; i=$(( $i + 1 )); echo result$i'"})
		o.Expect(cmdErr).NotTo(o.HaveOccurred())
		o.Expect(output).To(o.ContainSubstring("result1"))

		g.By("3. Run command with preserve-pod flag with pod-run-netns-command script")
		mustgatherDir = "/tmp/must-gather-55887-3"
		defer os.RemoveAll(mustgatherDir)
		output, cmdErr = collectMustGather(mustgatherDir, networkToolsImageStream, []string{"network-tools", "pod-run-netns-command", "--preserve-pod", ns, "hello-pod", "timeout 5 tcpdump"})
		o.Expect(cmdErr).NotTo(o.HaveOccurred())
		o.Expect(output).To(o.ContainSubstring("DONE"))
	})
})
