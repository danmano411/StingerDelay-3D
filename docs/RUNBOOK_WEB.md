# Run the web app

```bash
# API, from services/api
python -m venv .venv && .venv/Scripts/pip install -r requirements.txt
.venv/Scripts/python -m uvicorn main:app --port 8000

# Web, from apps/web
npm install && npm run dev
```

Open http://127.0.0.1:5173. To use another API port, set `VITE_API_BASE` in `apps/web/.env.local`.

Try: "Get me to Klaus by 8:30", then "walk that path", then "What's my Monday route?"

Optional keys go in the repo-root `.env`, which is git-ignored: `XAI_API_KEY`, `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET`. Without them the app uses the local parser, browser speech recognition and a labeled sample schedule.
