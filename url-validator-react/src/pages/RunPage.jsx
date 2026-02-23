import { useEffect, useState } from "react";
import { useParams } from "react-router-dom";
import api from "../api/client";

export default function RunPage() {
    const { id } = useParams();
    const [data, setData] = useState(null);

    useEffect(() => {
        let intervalId;

        const fetchRun = async () => {
            const res = await api.get(`/url_validation_runs/${id}`);
            setData(res.data);

            const status = res.data.report?.status;
            if (status === "completed" || status === "failed") {
                clearInterval(intervalId);
            }
        };

        fetchRun();
        intervalId = setInterval(fetchRun, 3000);

        return () => clearInterval(intervalId);
    }, [id]);

    if (!data) return <div style={{ padding: 24 }}>Loading...</div>;

    const { report, breakdown, samples } = data;

    return (
        <div style={{ padding: 24 }}>
            <h1>Validation Run #{report.id}</h1>
            <p>Status: {report.status}</p>
            <p>Progress: {report.processed_count} / {report.total_count}</p>
            <p>Valid: {report.valid_count} | Invalid: {report.invalid_count}</p>
            <p>Progress %: {report.progress_pct}</p>

            <h2>Breakdown</h2>
            <pre>{JSON.stringify(breakdown, null, 2)}</pre>

            <h2>Invalid Samples</h2>
            <pre>{JSON.stringify(samples?.invalid_jobs || [], null, 2)}</pre>

            <a href={`/api/v1/url_validation_runs/${report.id}/invalids_csv`}>
                Download invalids CSV
            </a>
        </div>
    );
}
