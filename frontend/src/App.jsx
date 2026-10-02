import { useEffect, useState } from "react";
import "./App.css";

const API_URL =
  import.meta.env.VITE_API_URL || "";

function App() {
  const [apiStatus, setApiStatus] = useState("Checking...");
  const [apiVersion, setApiVersion] = useState("-");
  const [error, setError] = useState("");

  useEffect(() => {
    async function checkAPI() {
      try {
        const response = await fetch(`${API_URL}/health`);

        if (!response.ok) {
          throw new Error(`HTTP ${response.status}`);
        }

        const data = await response.json();

        setApiStatus(data.status);
        setApiVersion(data.version);
      } catch (err) {
        setApiStatus("unavailable");
        setError(err.message);
      }
    }

    checkAPI();
  }, []);

  return (
    <main className="container">
      <section className="hero">
        <p className="eyebrow">AWS EKS OPERATIONS PROJECT</p>

        <h1>OpsFlow</h1>

        <p className="subtitle">
          Incident Management & Kubernetes Operations Platform
        </p>
      </section>

      <section className="card">
        <h2>Platform Status</h2>

        <div className="status-row">
          <span>Frontend</span>
          <strong className="healthy">healthy</strong>
        </div>

        <div className="status-row">
          <span>Backend API</span>
          <strong>{apiStatus}</strong>
        </div>

        <div className="status-row">
          <span>API Version</span>
          <strong>{apiVersion}</strong>
        </div>

        {error && (
          <p className="error">
            Backend connection failed: {error}
          </p>
        )}
      </section>

      <section className="card">
        <h2>Project Purpose</h2>

        <p>
          This application is used to demonstrate containerization,
          Kubernetes orchestration, AWS EKS, CI/CD, observability,
          security, autoscaling and production troubleshooting.
        </p>
      </section>
    </main>
  );
}

export default App;