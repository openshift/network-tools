all: images
.PHONY: all

# Include the library makefile
include $(addprefix ./vendor/github.com/openshift/library-go/alpha-build-machinery/make/, \
	targets/openshift/images.mk \
)

IMAGE_REGISTRY :=registry.svc.ci.openshift.org

# This will call a macro called "build-image" which will generate image specific targets based on the parameters:
# $0 - macro name
# $1 - target name
# $2 - image ref
# $3 - Dockerfile path
# $4 - context directory for image build
$(call build-image,ocp-debug-network,$(IMAGE_REGISTRY)/ocp/4.6:ocp-debug-network, ./Dockerfile.rhel7,.)
