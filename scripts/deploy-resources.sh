#!/bin/bash

set -e

RESOURCES_DIR="kubernetes/resources"
NAMESPACE_FILE="namespace.yaml"

echo "========================================="
echo "  Kubernetes Resources Deployment"
echo "========================================="
echo ""

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl is not installed or not in PATH"
    exit 1
fi

# Check if resources directory exists
if [ ! -d "$RESOURCES_DIR" ]; then
    echo "❌ Resources directory '$RESOURCES_DIR' not found"
    exit 1
fi

echo "📁 Deploying resources from: $RESOURCES_DIR"
echo ""

# Step 1: Deploy namespace first
echo "========================================="
echo "  Step 1: Creating Namespace"
echo "========================================="
echo ""

if [ -f "$RESOURCES_DIR/$NAMESPACE_FILE" ]; then
    echo "📋 Applying namespace configuration..."
    kubectl apply -f "$RESOURCES_DIR/$NAMESPACE_FILE"
    echo "✅ Namespace created successfully"
else
    echo "⚠️  Namespace file not found: $RESOURCES_DIR/$NAMESPACE_FILE"
    echo "   Continuing with other resources..."
fi

echo ""

# Step 2: Deploy all other resources (excluding namespace)
echo "========================================="
echo "  Step 2: Deploying Application Resources"
echo "========================================="
echo ""

# Find all YAML files except namespace.yaml
OTHER_RESOURCES=$(find "$RESOURCES_DIR" -name "*.yaml" -o -name "*.yml" | grep -v "$NAMESPACE_FILE" | sort)

if [ -z "$OTHER_RESOURCES" ]; then
    echo "⚠️  No additional resources found to deploy"
else
    echo "📋 Found the following resources to deploy:"
    echo "$OTHER_RESOURCES" | sed 's/^/   - /'
    echo ""
    
    for resource in $OTHER_RESOURCES; do
        echo "Applying: $(basename "$resource")"
        if kubectl apply -f "$resource"; then
            echo "✅ $(basename "$resource") applied successfully"
        else
            echo "❌ Failed to apply $(basename "$resource")"
            exit 1
        fi
        echo ""
    done
fi

# Step 3: Verify deployments
echo "========================================="
echo "  Step 3: Verification"
echo "========================================="
echo ""

# Check if greeter namespace exists and get resources
if kubectl get namespace greeter &> /dev/null; then
    echo "📊 Resources in greeter namespace:"
    kubectl get all -n greeter
    echo ""
    
    # Check Linkerd injection status
    echo "🔗 Linkerd injection status:"
    kubectl get pods -n greeter -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.metadata.annotations.linkerd\.io/inject}{"\n"}{end}' | column -t
    echo ""
    
    # Wait for pods to be ready
    echo "⏳ Waiting for pods to be ready..."
    if kubectl wait --for=condition=ready pod --all -n greeter --timeout=120s; then
        echo "✅ All pods are ready"
    else
        echo "⚠️  Some pods may still be starting"
    fi
else
    echo "ℹ️  Greeter namespace not found, checking default namespace"
    kubectl get all
fi

echo ""
echo "========================================="
echo "  🎉 Deployment Complete!"
echo "========================================="
echo ""
echo "Useful commands:"
echo "• Check pod status: kubectl get pods -n greeter"
echo "• View logs: kubectl logs -n greeter deployment/comms-service"
echo "• Check Linkerd injection: linkerd -n greeter check --proxy"
echo "• Port forward to service: kubectl port-forward -n greeter svc/comms-service 3000:3000"
echo "• View Linkerd dashboard: linkerd viz dashboard"