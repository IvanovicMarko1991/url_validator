import { BrowserRouter, Routes, Route } from "react-router-dom";
import UploadPage from "./pages/UploadPage";
import RunPage from "./pages/RunPage";

export default function App() {
    return (
        <BrowserRouter>
            <Routes>
                <Route path="/" element={<UploadPage />} />
                <Route path="/runs/:id" element={<RunPage />} />
            </Routes>
        </BrowserRouter>
    );
}
