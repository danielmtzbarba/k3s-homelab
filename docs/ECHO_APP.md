# Echo App

This document deploys a trivial workload after the server and first worker are healthy.

Purpose:

- verify scheduling across two nodes
- verify Service routing
- verify Ingress exposure through Traefik

## 1. Deploy the App

From the repository root:

```bash
kubectl apply -f manifests/echo-app.yaml
```

## 2. Verify Scheduling

```bash
kubectl get pods -o wide
kubectl get deploy,svc,ingress
```

Expected result:

- two `echo-app` pods
- ideally one pod on the server and one on the worker

The manifest uses preferred pod anti-affinity, so the scheduler should try to spread them across nodes.

## 3. Test the Service From Inside the Cluster

```bash
kubectl run curl --rm -it --restart=Never --image=curlimages/curl -- \
  curl -s http://echo-app.default.svc.cluster.local
```

## 4. Test the Ingress

Find the server public IP:

```bash
kubectl get nodes -o wide
```

Then from your local machine:

```bash
curl http://YOUR_SERVER_PUBLIC_IP/echo
```

Expected response:

```text
hello from k3s-homelab
```

## 5. Watch Load Balancing

Scale the deployment to make routing behavior more obvious:

```bash
kubectl scale deployment echo-app --replicas=4
kubectl get pods -o wide
```

If you want to stop the workload without deleting the objects:

```bash
kubectl scale deployment echo-app --replicas=0
```

If you want to force the pods to restart while keeping the deployment:

```bash
kubectl delete pod -l app=echo-app
```

## 6. Clean Up

```bash
kubectl delete -f manifests/echo-app.yaml
```

That removes:

- Deployment
- Service
- Ingress
