-- Passerelle · structure initiale de la base (copie fidèle du projet d'origine, 7 novembre 2026)
-- Partie 3 : déclencheurs, droits sur les tables, règles d'accès et stockage

-- ============ Déclencheurs automatiques ============
CREATE TRIGGER action_plans_updated_at BEFORE UPDATE ON public.action_plans FOR EACH ROW EXECUTE FUNCTION private.set_updated_at();
CREATE TRIGGER advisor_links_guard BEFORE INSERT OR UPDATE ON public.advisor_links FOR EACH ROW EXECUTE FUNCTION private.advisor_links_guard();
CREATE TRIGGER advisor_links_updated_at BEFORE UPDATE ON public.advisor_links FOR EACH ROW EXECUTE FUNCTION private.set_updated_at();
CREATE TRIGGER app_state_updated_at BEFORE UPDATE ON public.app_state FOR EACH ROW EXECUTE FUNCTION private.set_updated_at();
CREATE TRIGGER applications_updated_at BEFORE UPDATE ON public.applications FOR EACH ROW EXECUTE FUNCTION private.set_updated_at();
CREATE TRIGGER audit_events_immutable BEFORE DELETE OR UPDATE ON public.audit_events FOR EACH ROW EXECUTE FUNCTION private.audit_immutable();
CREATE TRIGGER biz_forecasts_updated_at BEFORE UPDATE ON public.biz_forecasts FOR EACH ROW EXECUTE FUNCTION private.set_updated_at();
CREATE TRIGGER biz_projects_updated_at BEFORE UPDATE ON public.biz_projects FOR EACH ROW EXECUTE FUNCTION private.set_updated_at();
CREATE TRIGGER career_tracks_updated_at BEFORE UPDATE ON public.career_tracks FOR EACH ROW EXECUTE FUNCTION private.set_updated_at();
CREATE TRIGGER consents_guard BEFORE UPDATE ON public.consents FOR EACH ROW EXECUTE FUNCTION private.consents_guard();
CREATE TRIGGER cv_profiles_updated_at BEFORE UPDATE ON public.cv_profiles FOR EACH ROW EXECUTE FUNCTION private.set_updated_at();
CREATE TRIGGER interview_preps_updated_at BEFORE UPDATE ON public.interview_preps FOR EACH ROW EXECUTE FUNCTION private.set_updated_at();
CREATE TRIGGER organizations_updated_at BEFORE UPDATE ON public.organizations FOR EACH ROW EXECUTE FUNCTION private.set_updated_at();
CREATE TRIGGER profiles_updated_at BEFORE UPDATE ON public.profiles FOR EACH ROW EXECUTE FUNCTION private.set_updated_at();
CREATE TRIGGER recommendations_guard BEFORE UPDATE ON public.recommendations FOR EACH ROW EXECUTE FUNCTION private.recommendations_guard();
CREATE TRIGGER on_auth_user_created AFTER INSERT ON auth.users FOR EACH ROW EXECUTE FUNCTION private.handle_new_user();
CREATE TRIGGER video_cvs_consent BEFORE INSERT OR UPDATE ON public.video_cvs FOR EACH ROW EXECUTE FUNCTION private.video_cvs_consent();
CREATE TRIGGER video_cvs_updated_at BEFORE UPDATE ON public.video_cvs FOR EACH ROW EXECUTE FUNCTION private.set_updated_at();

-- ============ Droits sur les tables ============
revoke all on all tables in schema public from anon, authenticated;
grant all on all tables in schema public to service_role;
grant select on all tables in schema public to authenticated;
grant insert, update, delete on public.action_plans, public.advisor_links, public.application_events, public.applications,
  public.assessment_reports, public.assessments, public.biz_forecasts, public.biz_projects, public.career_tracks,
  public.consents, public.cv_profiles, public.documents, public.interview_preps, public.progress_steps,
  public.recommendations, public.video_cvs to authenticated;
grant delete on public.app_state to authenticated;
grant update on public.profiles to authenticated;
revoke usage, select on all sequences in schema public from anon;

-- ============ Règles d'accès (RLS) ============
alter table public.action_plans enable row level security;
alter table public.advisor_links enable row level security;
alter table public.app_state enable row level security;
alter table public.app_state_snapshots enable row level security;
alter table public.application_events enable row level security;
alter table public.applications enable row level security;
alter table public.assessment_reports enable row level security;
alter table public.assessments enable row level security;
alter table public.audit_events enable row level security;
alter table public.biz_forecasts enable row level security;
alter table public.biz_projects enable row level security;
alter table public.career_tracks enable row level security;
alter table public.consents enable row level security;
alter table public.cv_profiles enable row level security;
alter table public.documents enable row level security;
alter table public.interview_preps enable row level security;
alter table public.organization_members enable row level security;
alter table public.organizations enable row level security;
alter table public.profiles enable row level security;
alter table public.progress_steps enable row level security;
alter table public.recommendations enable row level security;
alter table public.user_roles enable row level security;
alter table public.video_cvs enable row level security;

create policy "ajout : propriétaire" on public.action_plans as PERMISSIVE for INSERT to authenticated with check ((user_id = ( SELECT auth.uid() AS uid)));
create policy "lecture : propriétaire ou professionnel lié (progression)" on public.action_plans as PERMISSIVE for SELECT to authenticated using (private.can_view(user_id, 'progression'::text));
create policy "modification : propriétaire" on public.action_plans as PERMISSIVE for UPDATE to authenticated using ((user_id = ( SELECT auth.uid() AS uid))) with check ((user_id = ( SELECT auth.uid() AS uid)));
create policy "suppression : propriétaire" on public.action_plans as PERMISSIVE for DELETE to authenticated using ((user_id = ( SELECT auth.uid() AS uid)));
create policy "liens : demande par un professionnel" on public.advisor_links as PERMISSIVE for INSERT to authenticated with check (((professional_id = ( SELECT auth.uid() AS uid)) AND private.has_role('conseiller'::public.app_role)));
create policy "liens : lecture par les deux parties" on public.advisor_links as PERMISSIVE for SELECT to authenticated using (((beneficiary_id = ( SELECT auth.uid() AS uid)) OR (professional_id = ( SELECT auth.uid() AS uid))));
create policy "liens : mise à jour par les deux parties" on public.advisor_links as PERMISSIVE for UPDATE to authenticated using (((beneficiary_id = ( SELECT auth.uid() AS uid)) OR (professional_id = ( SELECT auth.uid() AS uid)))) with check (((beneficiary_id = ( SELECT auth.uid() AS uid)) OR (professional_id = ( SELECT auth.uid() AS uid))));
create policy "état : lecture du sien" on public.app_state as PERMISSIVE for SELECT to authenticated using ((user_id = ( SELECT auth.uid() AS uid)));
create policy "état : suppression du sien" on public.app_state as PERMISSIVE for DELETE to authenticated using ((user_id = ( SELECT auth.uid() AS uid)));
create policy "copies d'état : lecture des siennes" on public.app_state_snapshots as PERMISSIVE for SELECT to authenticated using ((user_id = ( SELECT auth.uid() AS uid)));
create policy "ajout : propriétaire" on public.application_events as PERMISSIVE for INSERT to authenticated with check ((user_id = ( SELECT auth.uid() AS uid)));
create policy "lecture : propriétaire ou professionnel lié (candidatures)" on public.application_events as PERMISSIVE for SELECT to authenticated using (private.can_view(user_id, 'candidatures'::text));
create policy "modification : propriétaire" on public.application_events as PERMISSIVE for UPDATE to authenticated using ((user_id = ( SELECT auth.uid() AS uid))) with check ((user_id = ( SELECT auth.uid() AS uid)));
create policy "suppression : propriétaire" on public.application_events as PERMISSIVE for DELETE to authenticated using ((user_id = ( SELECT auth.uid() AS uid)));
create policy "ajout : propriétaire" on public.applications as PERMISSIVE for INSERT to authenticated with check ((user_id = ( SELECT auth.uid() AS uid)));
create policy "lecture : propriétaire ou professionnel lié (candidatures)" on public.applications as PERMISSIVE for SELECT to authenticated using (private.can_view(user_id, 'candidatures'::text));
create policy "modification : propriétaire" on public.applications as PERMISSIVE for UPDATE to authenticated using ((user_id = ( SELECT auth.uid() AS uid))) with check ((user_id = ( SELECT auth.uid() AS uid)));
create policy "suppression : propriétaire" on public.applications as PERMISSIVE for DELETE to authenticated using ((user_id = ( SELECT auth.uid() AS uid)));
create policy "ajout : propriétaire" on public.assessment_reports as PERMISSIVE for INSERT to authenticated with check ((user_id = ( SELECT auth.uid() AS uid)));
create policy "lecture : propriétaire ou professionnel lié (bilan)" on public.assessment_reports as PERMISSIVE for SELECT to authenticated using (private.can_view(user_id, 'bilan'::text));
create policy "modification : propriétaire" on public.assessment_reports as PERMISSIVE for UPDATE to authenticated using ((user_id = ( SELECT auth.uid() AS uid))) with check ((user_id = ( SELECT auth.uid() AS uid)));
create policy "suppression : propriétaire" on public.assessment_reports as PERMISSIVE for DELETE to authenticated using ((user_id = ( SELECT auth.uid() AS uid)));
create policy "ajout : propriétaire" on public.assessments as PERMISSIVE for INSERT to authenticated with check ((user_id = ( SELECT auth.uid() AS uid)));
create policy "lecture : propriétaire ou professionnel lié (bilan)" on public.assessments as PERMISSIVE for SELECT to authenticated using (private.can_view(user_id, 'bilan'::text));
create policy "modification : propriétaire" on public.assessments as PERMISSIVE for UPDATE to authenticated using ((user_id = ( SELECT auth.uid() AS uid))) with check ((user_id = ( SELECT auth.uid() AS uid)));
create policy "suppression : propriétaire" on public.assessments as PERMISSIVE for DELETE to authenticated using ((user_id = ( SELECT auth.uid() AS uid)));
create policy "journal : lecture par les administrateurs" on public.audit_events as PERMISSIVE for SELECT to authenticated using (private.has_role('admin'::public.app_role));
create policy "ajout : propriétaire" on public.biz_forecasts as PERMISSIVE for INSERT to authenticated with check ((user_id = ( SELECT auth.uid() AS uid)));
create policy "lecture : propriétaire ou professionnel lié (projet)" on public.biz_forecasts as PERMISSIVE for SELECT to authenticated using (private.can_view(user_id, 'projet'::text));
create policy "modification : propriétaire" on public.biz_forecasts as PERMISSIVE for UPDATE to authenticated using ((user_id = ( SELECT auth.uid() AS uid))) with check ((user_id = ( SELECT auth.uid() AS uid)));
create policy "suppression : propriétaire" on public.biz_forecasts as PERMISSIVE for DELETE to authenticated using ((user_id = ( SELECT auth.uid() AS uid)));
create policy "ajout : propriétaire" on public.biz_projects as PERMISSIVE for INSERT to authenticated with check ((user_id = ( SELECT auth.uid() AS uid)));
create policy "lecture : propriétaire ou professionnel lié (projet)" on public.biz_projects as PERMISSIVE for SELECT to authenticated using (private.can_view(user_id, 'projet'::text));
create policy "modification : propriétaire" on public.biz_projects as PERMISSIVE for UPDATE to authenticated using ((user_id = ( SELECT auth.uid() AS uid))) with check ((user_id = ( SELECT auth.uid() AS uid)));
create policy "suppression : propriétaire" on public.biz_projects as PERMISSIVE for DELETE to authenticated using ((user_id = ( SELECT auth.uid() AS uid)));
create policy "ajout : propriétaire" on public.career_tracks as PERMISSIVE for INSERT to authenticated with check ((user_id = ( SELECT auth.uid() AS uid)));
create policy "lecture : propriétaire ou professionnel lié (progression)" on public.career_tracks as PERMISSIVE for SELECT to authenticated using (private.can_view(user_id, 'progression'::text));
create policy "modification : propriétaire" on public.career_tracks as PERMISSIVE for UPDATE to authenticated using ((user_id = ( SELECT auth.uid() AS uid))) with check ((user_id = ( SELECT auth.uid() AS uid)));
create policy "suppression : propriétaire" on public.career_tracks as PERMISSIVE for DELETE to authenticated using ((user_id = ( SELECT auth.uid() AS uid)));
create policy "consentements : ajout pour soi" on public.consents as PERMISSIVE for INSERT to authenticated with check (((user_id = ( SELECT auth.uid() AS uid)) AND (withdrawn_at IS NULL)));
create policy "consentements : lecture des siens" on public.consents as PERMISSIVE for SELECT to authenticated using ((user_id = ( SELECT auth.uid() AS uid)));
create policy "consentements : retrait des siens" on public.consents as PERMISSIVE for UPDATE to authenticated using ((user_id = ( SELECT auth.uid() AS uid))) with check ((user_id = ( SELECT auth.uid() AS uid)));
create policy "ajout : propriétaire" on public.cv_profiles as PERMISSIVE for INSERT to authenticated with check ((user_id = ( SELECT auth.uid() AS uid)));
create policy "lecture : propriétaire ou professionnel lié (cv)" on public.cv_profiles as PERMISSIVE for SELECT to authenticated using (private.can_view(user_id, 'cv'::text));
create policy "modification : propriétaire" on public.cv_profiles as PERMISSIVE for UPDATE to authenticated using ((user_id = ( SELECT auth.uid() AS uid))) with check ((user_id = ( SELECT auth.uid() AS uid)));
create policy "suppression : propriétaire" on public.cv_profiles as PERMISSIVE for DELETE to authenticated using ((user_id = ( SELECT auth.uid() AS uid)));
create policy "documents : ajout par le propriétaire" on public.documents as PERMISSIVE for INSERT to authenticated with check ((user_id = ( SELECT auth.uid() AS uid)));
create policy "documents : lecture propriétaire ou professionnel lié" on public.documents as PERMISSIVE for SELECT to authenticated using (private.can_view(user_id, private.document_scope(kind)));
create policy "documents : suppression par le propriétaire" on public.documents as PERMISSIVE for DELETE to authenticated using ((user_id = ( SELECT auth.uid() AS uid)));
create policy "ajout : propriétaire" on public.interview_preps as PERMISSIVE for INSERT to authenticated with check ((user_id = ( SELECT auth.uid() AS uid)));
create policy "lecture : propriétaire ou professionnel lié (candidatures)" on public.interview_preps as PERMISSIVE for SELECT to authenticated using (private.can_view(user_id, 'candidatures'::text));
create policy "modification : propriétaire" on public.interview_preps as PERMISSIVE for UPDATE to authenticated using ((user_id = ( SELECT auth.uid() AS uid))) with check ((user_id = ( SELECT auth.uid() AS uid)));
create policy "suppression : propriétaire" on public.interview_preps as PERMISSIVE for DELETE to authenticated using ((user_id = ( SELECT auth.uid() AS uid)));
create policy "membres : lecture par soi et les admins" on public.organization_members as PERMISSIVE for SELECT to authenticated using (((user_id = ( SELECT auth.uid() AS uid)) OR private.has_role('admin'::public.app_role)));
create policy "structures : lecture par les membres et les admins" on public.organizations as PERMISSIVE for SELECT to authenticated using ((private.has_role('admin'::public.app_role) OR (EXISTS ( SELECT 1
   FROM public.organization_members m
  WHERE ((m.organization_id = organizations.id) AND (m.user_id = ( SELECT auth.uid() AS uid)))))));
create policy "profil : lecture par soi ou un professionnel lié" on public.profiles as PERMISSIVE for SELECT to authenticated using (((id = ( SELECT auth.uid() AS uid)) OR private.is_linked(id) OR private.has_role('admin'::public.app_role)));
create policy "profil : modification par soi" on public.profiles as PERMISSIVE for UPDATE to authenticated using ((id = ( SELECT auth.uid() AS uid))) with check ((id = ( SELECT auth.uid() AS uid)));
create policy "ajout : propriétaire" on public.progress_steps as PERMISSIVE for INSERT to authenticated with check ((user_id = ( SELECT auth.uid() AS uid)));
create policy "lecture : propriétaire ou professionnel lié (progression)" on public.progress_steps as PERMISSIVE for SELECT to authenticated using (private.can_view(user_id, 'progression'::text));
create policy "modification : propriétaire" on public.progress_steps as PERMISSIVE for UPDATE to authenticated using ((user_id = ( SELECT auth.uid() AS uid))) with check ((user_id = ( SELECT auth.uid() AS uid)));
create policy "suppression : propriétaire" on public.progress_steps as PERMISSIVE for DELETE to authenticated using ((user_id = ( SELECT auth.uid() AS uid)));
create policy "recommandations : envoi par un professionnel lié" on public.recommendations as PERMISSIVE for INSERT to authenticated with check (((professional_id = ( SELECT auth.uid() AS uid)) AND private.is_linked(beneficiary_id)));
create policy "recommandations : lecture bénéficiaire ou auteur" on public.recommendations as PERMISSIVE for SELECT to authenticated using (((beneficiary_id = ( SELECT auth.uid() AS uid)) OR (professional_id = ( SELECT auth.uid() AS uid))));
create policy "recommandations : marquer comme lue" on public.recommendations as PERMISSIVE for UPDATE to authenticated using ((beneficiary_id = ( SELECT auth.uid() AS uid))) with check ((beneficiary_id = ( SELECT auth.uid() AS uid)));
create policy "recommandations : retrait par l'auteur" on public.recommendations as PERMISSIVE for DELETE to authenticated using ((professional_id = ( SELECT auth.uid() AS uid)));
create policy "rôles : lecture des siens, ou tous pour un admin" on public.user_roles as PERMISSIVE for SELECT to authenticated using (((user_id = ( SELECT auth.uid() AS uid)) OR private.has_role('admin'::public.app_role)));
create policy "ajout : propriétaire" on public.video_cvs as PERMISSIVE for INSERT to authenticated with check ((user_id = ( SELECT auth.uid() AS uid)));
create policy "lecture : propriétaire ou professionnel lié (cv)" on public.video_cvs as PERMISSIVE for SELECT to authenticated using (private.can_view(user_id, 'cv'::text));
create policy "modification : propriétaire" on public.video_cvs as PERMISSIVE for UPDATE to authenticated using ((user_id = ( SELECT auth.uid() AS uid))) with check ((user_id = ( SELECT auth.uid() AS uid)));
create policy "suppression : propriétaire" on public.video_cvs as PERMISSIVE for DELETE to authenticated using ((user_id = ( SELECT auth.uid() AS uid)));

-- ============ Stockage des documents ============
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('documents', 'documents', false, 52428800, array['application/pdf','application/vnd.openxmlformats-officedocument.wordprocessingml.document','image/jpeg','image/png','video/mp4','video/webm','video/quicktime','text/plain'])
on conflict (id) do nothing;

create policy "documents : le propriétaire dépose dans son dossier" on storage.objects as PERMISSIVE for INSERT to authenticated with check (((bucket_id = 'documents'::text) AND ((storage.foldername(name))[1] = (( SELECT auth.uid() AS uid))::text) AND ((storage.foldername(name))[2] = ANY (ARRAY['cv'::text, 'lettre'::text, 'cv_video'::text, 'business_plan'::text, 'autre'::text])) AND (array_length(storage.foldername(name), 1) = 2)));
create policy "documents : le propriétaire lit son dossier" on storage.objects as PERMISSIVE for SELECT to authenticated using (((bucket_id = 'documents'::text) AND ((storage.foldername(name))[1] = (( SELECT auth.uid() AS uid))::text)));
create policy "documents : le propriétaire remplace ses fichiers" on storage.objects as PERMISSIVE for UPDATE to authenticated using (((bucket_id = 'documents'::text) AND ((storage.foldername(name))[1] = (( SELECT auth.uid() AS uid))::text))) with check (((bucket_id = 'documents'::text) AND ((storage.foldername(name))[1] = (( SELECT auth.uid() AS uid))::text)));
create policy "documents : le propriétaire supprime ses fichiers" on storage.objects as PERMISSIVE for DELETE to authenticated using (((bucket_id = 'documents'::text) AND ((storage.foldername(name))[1] = (( SELECT auth.uid() AS uid))::text)));
create policy "documents : un professionnel lié lit les fichiers partagés" on storage.objects as PERMISSIVE for SELECT to authenticated using (((bucket_id = 'documents'::text) AND (EXISTS ( SELECT 1
   FROM public.documents d
  WHERE ((d.storage_path = objects.name) AND private.can_view(d.user_id, private.document_scope(d.kind)))))));
