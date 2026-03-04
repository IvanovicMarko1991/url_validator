import { BrowserRouter, Routes, Route } from "react-router-dom";
import UploadPage from "./pages/UploadPage";
import RunPage from "./pages/RunPage";
import RequireAuth from "./components/RequireAuth";

export default function App() {
    return (
        <BrowserRouter>
            <RequireAuth>
                <Routes>
                    <Route path="/" element={<UploadPage />} />
                    <Route path="/runs/:id" element={<RunPage />} />
                </Routes>
            </RequireAuth>
        </BrowserRouter>
    );
}
