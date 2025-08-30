#!/bin/bash

set -e

LINKERD_VERSION="${LINKERD_VERSION:-stable-2.14.10}"
INSTALL_DIR="${INSTALL_DIR:-/usr/local/bin}"
INSTALL_DASHBOARD="${INSTALL_DASHBOARD:-true}"

echo "========================================="
echo "  Linkerd Installation Script"
echo "========================================="
echo ""
echo "This script will:"
echo "1. Install the Linkerd CLI"
echo "2. Perform pre-installation checks"
echo "3. Install Linkerd CRDs"
echo "4. Install Linkerd control plane"
echo "5. Verify the installation"
if [ "$INSTALL_DASHBOARD" = "true" ]; then
    echo "6. Install Linkerd dashboard"
fi
echo ""
echo "Installing Linkerd CLI..."

# Detect OS and architecture
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)

case $ARCH in
    x86_64)
        ARCH="amd64"
        ;;
    aarch64|arm64)
        ARCH="arm64"
        ;;
    *)
        echo "Unsupported architecture: $ARCH"
        exit 1
        ;;
esac

# Download Linkerd CLI
LINKERD_URL="https://github.com/linkerd/linkerd2/releases/download/${LINKERD_VERSION}/linkerd2-cli-${LINKERD_VERSION}-${OS}-${ARCH}"

echo "Downloading Linkerd CLI from: $LINKERD_URL"
curl -sLO "$LINKERD_URL"

# Make it executable and move to install directory
chmod +x "linkerd2-cli-${LINKERD_VERSION}-${OS}-${ARCH}"
sudo mv "linkerd2-cli-${LINKERD_VERSION}-${OS}-${ARCH}" "${INSTALL_DIR}/linkerd"

echo "Linkerd CLI installed to ${INSTALL_DIR}/linkerd"

# Verify CLI installation
echo "Verifying CLI installation..."
linkerd version --client

echo ""
echo "========================================="
echo "  Step 2: Pre-installation Checks"
echo "========================================="
echo ""
echo "Checking cluster compatibility..."

if ! linkerd check --pre; then
    echo ""
    echo "❌ Pre-installation checks failed!"
    echo "Please fix the issues above before continuing."
    exit 1
fi

echo ""
echo "✅ Pre-installation checks passed!"

echo ""
echo "========================================="
echo "  Step 3: Installing Linkerd CRDs"
echo "========================================="
echo ""

if linkerd install --crds | kubectl apply -f -; then
    echo "✅ Linkerd CRDs installed successfully!"
else
    echo "❌ Failed to install Linkerd CRDs!"
    exit 1
fi

echo ""
echo "========================================="
echo "  Step 4: Installing Linkerd Control Plane"
echo "========================================="
echo ""

if linkerd install | kubectl apply -f -; then
    echo "✅ Linkerd control plane installed successfully!"
else
    echo "❌ Failed to install Linkerd control plane!"
    exit 1
fi

echo ""
echo "Waiting for control plane to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/linkerd-destination -n linkerd
kubectl wait --for=condition=available --timeout=300s deployment/linkerd-identity -n linkerd
kubectl wait --for=condition=available --timeout=300s deployment/linkerd-proxy-injector -n linkerd

echo ""
echo "========================================="
echo "  Step 5: Verifying Installation"
echo "========================================="
echo ""

if ! linkerd check; then
    echo ""
    echo "⚠️  Some checks failed. This might be normal during initial startup."
    echo "You can run 'linkerd check' again in a few minutes."
fi

if [ "$INSTALL_DASHBOARD" = "true" ]; then
    echo ""
    echo "========================================="
    echo "  Step 6: Installing Dashboard"
    echo "========================================="
    echo ""

    if linkerd viz install | kubectl apply -f -; then
        echo "✅ Linkerd dashboard installed successfully!"
        
        echo ""
        echo "Waiting for dashboard to be ready..."
        kubectl wait --for=condition=available --timeout=300s deployment/web -n linkerd-viz || true
        
        echo ""
        echo "Dashboard is ready! You can access it by running:"
        echo "  linkerd viz dashboard"
    else
        echo "❌ Failed to install Linkerd dashboard (non-critical)"
    fi
fi

echo ""
echo "========================================="
echo "  🎉 Linkerd Installation Complete!"
echo "========================================="
echo ""
echo "Useful Commands:"
echo ""
echo "• Check Linkerd status:"
echo "  linkerd check"
echo ""
echo "• Open dashboard:"
echo "  linkerd viz dashboard"
echo ""
echo "• Inject Linkerd proxy into a deployment:"
echo "  kubectl get deploy <deployment-name> -o yaml | linkerd inject - | kubectl apply -f -"
echo ""
echo "• Check traffic between services:"
echo "  linkerd viz stat deployments"
echo ""
echo "• View live traffic:"
echo "  linkerd viz top deployments"
echo ""
echo "• Generate traffic policies:"
echo "  linkerd viz authz -n <namespace>"
echo ""
echo "For more information, visit: https://linkerd.io/2/getting-started/"