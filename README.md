# Flask Sample App with Tests

This is a simple Flask web application with unit tests. The application provides a basic REST API for managing a list of items. It serves as a starting point for learning how to create a Flask application and write tests for it.

## Project Structure

The project is organized as follows:

- `app/`: Contains the Flask application and routes.
- `tests/`: Houses unit tests for the application.
- `run.py`: A script to run the Flask application.

## Getting Started

To get the Flask app up and running on your local machine, follow these steps:

1. **Clone the Repository:**

   ```bash
   git clone <repository_url>
   cd flask_sample_app
   ```

2. **Set Up a Virtual Environment:**

   It's recommended to create a virtual environment to isolate project dependencies.

   ```bash
   python -m venv venv
   source venv/bin/activate  # On Windows, use venv\Scripts\activate
   ```

3. **Install Dependencies:**

   Install the necessary dependencies using `pip`:

   ```bash
   pip install -r requirements.txt
   ```

4. **Run the Application:**

   Start the Flask application:

   ```bash
   python run.py
   ```

   The app will be available at [http://localhost:5000](http://localhost:5000).

5. **Run Tests:**

   To run the unit tests, execute the following command:

   ```bash
   python -m unittest discover tests
   ```

   This command will discover and run all tests in the `tests` directory.

## Published Container Image

The application image is published publicly on Docker Hub:

| | |
|---|---|
| Repository | [`abedadounkpe/msc-de1-flask-app`](https://hub.docker.com/r/abedadounkpe/msc-de1-flask-app) |
| Tag | `1.0.0` |
| Digest | `sha256:5fdab24f6872a3eea9819be137855708107d79a00329df96d7df66e8a5d7ee45` |
| Image ID | `fe5c693b2f05` |
| Size | 130 MB |

Pull by digest to guarantee you get this exact build (a tag can be moved to point at a
different image later; the digest is a hash of the image content and cannot be):

```bash
docker pull abedadounkpe/msc-de1-flask-app@sha256:5fdab24f6872a3eea9819be137855708107d79a00329df96d7df66e8a5d7ee45
```

The digest was captured locally with:

```bash
docker images --digests | findstr msc-de1-flask-app
```

```text
abedadounkpe/msc-de1-flask-app   1.0.0    sha256:5fdab24f6872a3eea9819be137855708107d79a00329df96d7df66e8a5d7ee45   fe5c693b2f05   130MB
abedadounkpe/msc-de1-flask-app   latest   sha256:5fdab24f6872a3eea9819be137855708107d79a00329df96d7df66e8a5d7ee45   fe5c693b2f05   130MB
```

Both tags resolve to the same digest, confirming `1.0.0` and `latest` are the same build.

### Pull and run the published image

No clone or build is required — these commands run the exact published image.

1. **Pull the image** (works without logging in, the repository is public):

   ```bash
   docker pull abedadounkpe/msc-de1-flask-app:1.0.0
   ```

2. **Run the container**, publishing container port 8000 on host port 8000:

   ```bash
   docker run -d -p 8000:8000 --name msc-de1-flask-app abedadounkpe/msc-de1-flask-app:1.0.0
   ```

   To run it with the same hardening applied in `compose.yaml` (non-root user, no
   capabilities, no privilege escalation, read-only root filesystem with a writable tmpfs
   for gunicorn's worker heartbeats, and CPU/memory limits):

   ```bash
   docker run -d -p 8000:8000 --name msc-de1-flask-app \
     --user 10001:10001 \
     --cap-drop ALL \
     --security-opt no-new-privileges:true \
     --read-only --tmpfs /tmp \
     --cpus 0.50 --memory 256m \
     abedadounkpe/msc-de1-flask-app:1.0.0
   ```

3. **Verify it is serving:**

   ```bash
   curl http://localhost:8000/
   curl http://localhost:8000/items
   ```

   Or open [http://localhost:8000](http://localhost:8000) in a browser.

4. **Inspect logs / stop and clean up:**

   ```bash
   docker logs msc-de1-flask-app
   docker stop msc-de1-flask-app
   docker rm msc-de1-flask-app
   ```

Alternatively, if you have the repository checked out, `docker compose up -d` starts the
same image with all of the above settings already declared in `compose.yaml`.

> **Note:** the container listens on port **8000** (gunicorn), not 5000. Port 5000 is only
> used by the Flask development server when running `python run.py` locally.

## Running on Kubernetes (kind)

The repository includes [`kind/kind-config.yaml`](kind/kind-config.yaml), which defines a
local cluster with one control-plane node and two workers. Requires
[kind](https://kind.sigs.k8s.io/) and `kubectl`, with Docker Desktop running.

### 1. Create the cluster

```bash
kind create cluster --name msc-de1 --config kind/kind-config.yaml
kubectl cluster-info --context kind-msc-de1
kubectl get nodes
```

You should see three nodes in `Ready` state.

### 2. Make the image available to the cluster

kind nodes have their own image store and cannot see the local Docker daemon's images, so
the image must be side-loaded (this also avoids a round trip to Docker Hub):

```bash
kind load docker-image abedadounkpe/msc-de1-flask-app:1.0.0 --name msc-de1
```

Because the tag is not `:latest`, the default pull policy is `IfNotPresent`, so the
side-loaded image is used rather than being re-pulled.

### 3. Deploy and expose the app

```bash
kubectl create deployment flask-app --image=abedadounkpe/msc-de1-flask-app:1.0.0 --replicas=3
kubectl expose deployment flask-app --name=flask-app --port=8000 --target-port=8000
```

Check that the pods are scheduled across the worker nodes:

```bash
kubectl get pods -o wide
kubectl get deployment,service flask-app
kubectl rollout status deployment/flask-app
```

### 4. Access the service

The kind config declares no host port mappings, so reach the service through a port-forward:

```bash
kubectl port-forward service/flask-app 8000:8000
```

Then, in a second terminal:

```bash
curl http://localhost:8000/
curl http://localhost:8000/items
```

### 5. Scaling and self-healing

```bash
# Scale out, then back in
kubectl scale deployment flask-app --replicas=5
kubectl get pods -w

# Delete a pod and watch the ReplicaSet recreate it
kubectl delete pod <pod-name>
kubectl get pods
```

### 6. Inspect and troubleshoot

```bash
kubectl logs -l app=flask-app --tail=50
kubectl describe deployment flask-app
kubectl describe pod <pod-name>
kubectl exec -it <pod-name> -- /bin/sh
kubectl get events --sort-by=.lastTimestamp
```

### 7. Tear down

```bash
kubectl delete service flask-app
kubectl delete deployment flask-app
kind delete cluster --name msc-de1
```

## Application Routes

The application provides the following routes:

- `GET /`: Returns a simple greeting message.
- `GET /items`: Returns a list of items.
- `GET /items/{item_id}`: Returns the details of a specific item.
- `POST /items`: Adds a new item to the list.

## Testing

Unit tests are provided in the `tests` directory. They cover the basic functionality of the application, including route handling and response validation. You can use these tests as a reference to write your own tests or to verify the correctness of the application.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Contribute

Feel free to contribute to this project by opening issues or submitting pull requests. We welcome any improvements, bug fixes, or additional features.

## Author

- Pan Luo

## Acknowledgments

- This project was created as a sample Flask application for educational purposes.
- Special thanks to the Flask community for providing a fantastic web framework.

Enjoy experimenting with the Flask sample app! If you have any questions or need further assistance, please don't hesitate to reach out.
