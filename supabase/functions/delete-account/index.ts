// Supprime le compte de la personne connectée, ses fichiers et toutes ses données (droit à l'effacement).
import { createClient } from "npm:@supabase/supabase-js@2.45.4";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "Méthode non autorisée" }, 405);

  const token = (req.headers.get("Authorization") || "").replace(/^Bearer\s+/i, "");
  const admin = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const { data: { user }, error } = await admin.auth.getUser(token);
  if (error || !user) return json({ error: "Connexion requise" }, 401);

  // 1. Fichiers déposés par la personne (dossier documents/<id>/<type>/...)
  const bucket = admin.storage.from("documents");
  for (const kind of ["cv", "lettre", "cv_video", "business_plan", "autre"]) {
    const { data: files } = await bucket.list(`${user.id}/${kind}`, { limit: 1000 });
    if (files && files.length) await bucket.remove(files.map((f) => `${user.id}/${kind}/${f.name}`));
  }

  // 2. Le compte : la suppression efface aussi le profil et toutes les tables liées (ON DELETE CASCADE)
  const { error: delErr } = await admin.auth.admin.deleteUser(user.id);
  if (delErr) return json({ error: "Suppression impossible" }, 500);

  return json({ ok: true });
});
