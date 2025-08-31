#!/bin/bash

set -e

echo "========================================="
echo "  Kubernetes + Linkerd Cleanup Script"
echo "========================================="
echo ""
echo "⚠️  WARNING: This will delete all resources created by this project!"
echo ""

# Confirmation prompt
read -p "Are you sure you want to proceed? This will delete the entire EKS cluster. (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cleanup cancelled."
    exit 1
fi

echo ""
echo "Starting cleanup process..."

# Step 1: Delete application resources
echo ""
echo "========================================="
echo "  Step 1: Deleting Application Resources"
echo "========================================="
echo ""

RESOURCES_DIR="kubernetes/resources"

if [ -d "$RESOURCES_DIR" ]; then
    echo "📋 Deleting resources from: $RESOURCES_DIR"
    
    # Delete all resources except namespace (delete namespace last)
    find "$RESOURCES_DIR" -name "*.yaml" -o -name "*.yml" | grep -v "namespace.yaml" | while read -r resource; do
        echo "Deleting: $(basename "$resource")"
        kubectl delete -f "$resource" --ignore-not-found=true
    done
    
    # Delete namespace last
    if [ -f "$RESOURCES_DIR/namespace.yaml" ]; then
        echo "Deleting: namespace.yaml"
        kubectl delete -f "$RESOURCES_DIR/namespace.yaml" --ignore-not-found=true
    fi
    
    echo "✅ Application resources deleted"
else
    echo "⚠️  Resources directory not found: $RESOURCES_DIR"
fi

# Step 2: Uninstall Linkerd
echo ""
echo "========================================="
echo "  Step 2: Uninstalling Linkerd"
echo "========================================="
echo ""

echo "Checking if Linkerd is installed..."

if kubectl get namespace linkerd &> /dev/null; then
    echo "📋 Uninstalling Linkerd dashboard..."
    linkerd viz uninstall --ignore-not-found | kubectl delete -f - || echo "Dashboard uninstall completed"
    
    echo ""
    echo "📋 Uninstalling Linkerd control plane..."
    linkerd uninstall --ignore-not-found | kubectl delete -f - || echo "Control plane uninstall completed"
    
    # Wait for namespaces to be fully deleted
    echo ""
    echo "⏳ Waiting for Linkerd namespaces to be deleted..."
    kubectl wait --for=delete namespace/linkerd --timeout=120s || true
    kubectl wait --for=delete namespace/linkerd-viz --timeout=120s || true
    
    echo "✅ Linkerd uninstalled successfully"
else
    echo "ℹ️  Linkerd not found, skipping uninstall"
fi

# Step 3: Delete EKS cluster
echo ""
echo "========================================="
echo "  Step 3: Deleting EKS Cluster"
echo "========================================="
echo ""

CLUSTER_CONFIG="kubernetes/cluster/cluster-config.yaml"

if [ -f "$CLUSTER_CONFIG" ]; then
    echo "📋 Deleting EKS cluster using: $CLUSTER_CONFIG"
    echo ""
    echo "⚠️  This may take 10-15 minutes..."
    
    if eksctl delete cluster -f "$CLUSTER_CONFIG"; then
        echo "✅ EKS cluster deleted successfully"
    else
        echo "❌ Failed to delete EKS cluster"
        echo "You may need to delete it manually from the AWS console or retry the command"
        exit 1
    fi
else
    echo "❌ Cluster configuration not found: $CLUSTER_CONFIG"
    echo "You may need to delete the cluster manually:"
    echo "  eksctl delete cluster --name=sandbox --region=us-west-2"
    exit 1
fi

# Step 4: Cleanup local files (optional)
echo ""
echo "========================================="
echo "  Step 4: Local Cleanup (Optional)"
echo "========================================="
echo ""

echo "Local cleanup options:"
echo "• Remove kubeconfig entries: kubectl config delete-context <context-name>"
echo "• Clean AWS credentials cache: rm -rf ~/.aws/cli/cache"
echo "• Remove local Linkerd CLI: sudo rm -f /usr/local/bin/linkerd"

echo ""
echo "========================================="
echo "  🎉 Cleanup Complete!"
echo "========================================="
echo ""
echo "Summary of what was deleted:"
echo "• Application resources (greeter namespace, services, pods)"
echo "• Linkerd service mesh (control plane and dashboard)"
echo "• EKS cluster and all associated AWS resources"
echo ""
echo "The project files remain intact for future use."
echo "Run './scripts/install-linkerd.sh' and './scripts/deploy-resources.sh' to recreate everything."