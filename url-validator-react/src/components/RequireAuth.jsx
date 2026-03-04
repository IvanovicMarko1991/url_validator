import { useEffect, useState } from "react";
import api from "../api/client";

export default function RequireAuth({ children }) {
    const [ready, setReady] = useState(false);

    useEffect(() => {
        api.get("/me")
            .then(() => setReady(true))
            .catch(() => {
                window.location.href = "http://localhost:3000/users/sign_in";
            });
    }, []);

    if (!ready) return <div style={{ padding: 24 }}>Checking session...</div>;
    return children;
}
