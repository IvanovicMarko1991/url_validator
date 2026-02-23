import { useState } from "react";
import { useNavigate } from "react-router-dom";
import api from "../api/client";

export default function UploadPage() {
    const [file, setFile] = useState(null);
    const [loading, setLoading] = useState(false);
    const navigate = useNavigate();

    const handleSubmit = async (e) => {
        e.preventDefault();
        if (!file) return;

        const formData = new FormData();
        formData.append("file", file);

        setLoading(true);
        try {
            const response = await api.post("/csv_imports", formData);
            const runId = response.data.validation_run.id;
            navigate(`/runs/${runId}`);
        } catch (error) {
            console.error(error);
            alert("Upload failed");
        } finally {
            setLoading(false);
        }
    };

    return (
        <div style={{ padding: 24 }}>
            <h1>URL Validator</h1>
            <form onSubmit={handleSubmit}>
                <input
                    type="file"
                    accept=".csv"
                    onChange={(e) => setFile(e.target.files?.[0] || null)}
                />
                <button type="submit" disabled={!file || loading}>
                    {loading ? "Uploading..." : "Upload CSV"}
                </button>
            </form>
        </div>
    );
}
