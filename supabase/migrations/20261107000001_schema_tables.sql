-- Passerelle · structure initiale de la base (copie fidèle du projet d'origine, 7 novembre 2026)
-- Seule différence volontaire : le rôle « authenticated » n'a plus le droit TRUNCATE (inutile et contourne les règles d'accès).

create extension if not exists pgcrypto with schema extensions;

create schema if not exists private;
grant usage on schema private to authenticated, service_role;

-- ============ Types ============
create type public.app_role as enum ('conseiller', 'admin_contenu', 'admin');
create type public.application_status as enum ('brouillon', 'relue', 'envoyee', 'relancee', 'interet', 'entretien', 'refus', 'abandon');
create type public.audience as enum ('jeunes', 'adultes', 'seniors');
create type public.consent_purpose as enum ('cgu', 'confidentialite', 'import_local', 'partage_conseiller', 'stockage_cv_video', 'analyse_automatique');
create type public.document_kind as enum ('cv', 'lettre', 'cv_video', 'business_plan', 'autre');
create type public.link_status as enum ('demande', 'actif', 'refuse', 'revoque');
create type public.track_status as enum ('proposee', 'retenue', 'ecartee');

-- ============ Tables ============
create table public.audit_events (
  id bigint generated always as identity not null,
  occurred_at timestamp with time zone default now() not null,
  actor_id uuid,
  action text not null,
  target_table text,
  target_id text,
  detail jsonb default '{}'::jsonb not null
);

create table public.profiles (
  id uuid not null,
  display_name text,
  audience public.audience,
  locale text default 'fr'::text not null,
  preferences jsonb default '{}'::jsonb not null,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null
);

create table public.user_roles (
  user_id uuid not null,
  role public.app_role not null,
  granted_by uuid,
  granted_at timestamp with time zone default now() not null
);

create table public.consents (
  id uuid default gen_random_uuid() not null,
  user_id uuid not null,
  purpose public.consent_purpose not null,
  text_version text not null,
  granted_at timestamp with time zone default now() not null,
  withdrawn_at timestamp with time zone
);

create table public.organizations (
  id uuid default gen_random_uuid() not null,
  name text not null,
  kind text not null,
  siret text,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null
);

create table public.organization_members (
  organization_id uuid not null,
  user_id uuid not null,
  member_role text default 'conseiller'::text not null,
  added_by uuid,
  added_at timestamp with time zone default now() not null
);

create table public.advisor_links (
  id uuid default gen_random_uuid() not null,
  beneficiary_id uuid not null,
  professional_id uuid not null,
  organization_id uuid,
  status public.link_status default 'demande'::public.link_status not null,
  scopes text[] default '{}'::text[] not null,
  message text,
  created_at timestamp with time zone default now() not null,
  accepted_at timestamp with time zone,
  ended_at timestamp with time zone,
  updated_at timestamp with time zone default now() not null
);

create table public.app_state (
  user_id uuid not null,
  state jsonb not null,
  schema_version smallint default 1 not null,
  version bigint default 1 not null,
  device_label text,
  updated_at timestamp with time zone default now() not null
);

create table public.app_state_snapshots (
  id uuid default gen_random_uuid() not null,
  user_id uuid not null,
  state jsonb not null,
  version bigint not null,
  reason text not null,
  created_at timestamp with time zone default now() not null
);

create table public.documents (
  id uuid default gen_random_uuid() not null,
  user_id uuid not null,
  kind public.document_kind not null,
  storage_path text not null,
  filename text not null,
  mime_type text not null,
  size_bytes bigint not null,
  sha256 text,
  created_at timestamp with time zone default now() not null
);

create table public.cv_profiles (
  id uuid default gen_random_uuid() not null,
  user_id uuid not null,
  document_id uuid,
  title text,
  raw_text text,
  extracted jsonb default '{}'::jsonb not null,
  is_current boolean default true not null,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null
);

create table public.video_cvs (
  user_id uuid not null,
  document_id uuid,
  external_url text,
  target_role text,
  script text,
  analysis jsonb,
  explainer_seen boolean default false not null,
  updated_at timestamp with time zone default now() not null
);

create table public.assessments (
  id uuid default gen_random_uuid() not null,
  user_id uuid not null,
  test_code text not null,
  answers jsonb default '{}'::jsonb not null,
  result jsonb,
  started_at timestamp with time zone default now() not null,
  completed_at timestamp with time zone
);

create table public.assessment_reports (
  id uuid default gen_random_uuid() not null,
  user_id uuid not null,
  source text not null,
  content jsonb not null,
  created_at timestamp with time zone default now() not null
);

create table public.career_tracks (
  id uuid default gen_random_uuid() not null,
  user_id uuid not null,
  job_title text not null,
  status public.track_status default 'proposee'::public.track_status not null,
  reason text,
  source text default 'bilan'::text not null,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null
);

create table public.action_plans (
  id uuid default gen_random_uuid() not null,
  user_id uuid not null,
  track_id uuid,
  title text not null,
  steps jsonb default '[]'::jsonb not null,
  progress smallint default 0 not null,
  due_on date,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null
);

create table public.progress_steps (
  user_id uuid not null,
  path text not null,
  step text not null,
  done_at timestamp with time zone default now() not null
);

create table public.biz_projects (
  id uuid default gen_random_uuid() not null,
  user_id uuid not null,
  name text,
  project jsonb default '{}'::jsonb not null,
  validation jsonb default '{}'::jsonb not null,
  legal_status text,
  touched_fields text[] default '{}'::text[] not null,
  progress smallint default 0 not null,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null
);

create table public.biz_forecasts (
  project_id uuid not null,
  user_id uuid not null,
  data jsonb default '{}'::jsonb not null,
  updated_at timestamp with time zone default now() not null
);

create table public.applications (
  id uuid default gen_random_uuid() not null,
  user_id uuid not null,
  offer jsonb not null,
  status public.application_status default 'brouillon'::public.application_status not null,
  cover_letter text,
  include_video boolean default false not null,
  reviewed_at timestamp with time zone,
  sent_at timestamp with time zone,
  auto_followup boolean default false not null,
  followup_every_days smallint default 7 not null,
  followup_max smallint default 2 not null,
  next_followup_at timestamp with time zone,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null
);

create table public.application_events (
  id uuid default gen_random_uuid() not null,
  application_id uuid not null,
  user_id uuid not null,
  kind text not null,
  occurred_at timestamp with time zone default now() not null,
  detail text
);

create table public.interview_preps (
  id uuid default gen_random_uuid() not null,
  application_id uuid not null,
  user_id uuid not null,
  questions jsonb default '[]'::jsonb not null,
  notes text,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null
);

create table public.recommendations (
  id uuid default gen_random_uuid() not null,
  professional_id uuid,
  beneficiary_id uuid not null,
  kind text not null,
  title text not null,
  body text,
  url text,
  created_at timestamp with time zone default now() not null,
  read_at timestamp with time zone
);

-- ============ Clés et contrôles ============
alter table public.action_plans add constraint action_plans_pkey PRIMARY KEY (id);
alter table public.advisor_links add constraint advisor_links_pkey PRIMARY KEY (id);
alter table public.app_state add constraint app_state_pkey PRIMARY KEY (user_id);
alter table public.app_state_snapshots add constraint app_state_snapshots_pkey PRIMARY KEY (id);
alter table public.application_events add constraint application_events_pkey PRIMARY KEY (id);
alter table public.applications add constraint applications_pkey PRIMARY KEY (id);
alter table public.assessment_reports add constraint assessment_reports_pkey PRIMARY KEY (id);
alter table public.assessments add constraint assessments_pkey PRIMARY KEY (id);
alter table public.audit_events add constraint audit_events_pkey PRIMARY KEY (id);
alter table public.biz_forecasts add constraint biz_forecasts_pkey PRIMARY KEY (project_id);
alter table public.biz_projects add constraint biz_projects_pkey PRIMARY KEY (id);
alter table public.career_tracks add constraint career_tracks_pkey PRIMARY KEY (id);
alter table public.consents add constraint consents_pkey PRIMARY KEY (id);
alter table public.cv_profiles add constraint cv_profiles_pkey PRIMARY KEY (id);
alter table public.documents add constraint documents_pkey PRIMARY KEY (id);
alter table public.interview_preps add constraint interview_preps_pkey PRIMARY KEY (id);
alter table public.organization_members add constraint organization_members_pkey PRIMARY KEY (organization_id, user_id);
alter table public.organizations add constraint organizations_pkey PRIMARY KEY (id);
alter table public.profiles add constraint profiles_pkey PRIMARY KEY (id);
alter table public.progress_steps add constraint progress_steps_pkey PRIMARY KEY (user_id, path, step);
alter table public.recommendations add constraint recommendations_pkey PRIMARY KEY (id);
alter table public.user_roles add constraint user_roles_pkey PRIMARY KEY (user_id, role);
alter table public.video_cvs add constraint video_cvs_pkey PRIMARY KEY (user_id);
alter table public.applications add constraint applications_id_user_id_key UNIQUE (id, user_id);
alter table public.biz_projects add constraint biz_projects_id_user_id_key UNIQUE (id, user_id);
alter table public.career_tracks add constraint career_tracks_id_user_id_key UNIQUE (id, user_id);
alter table public.documents add constraint documents_id_user_id_key UNIQUE (id, user_id);
alter table public.documents add constraint documents_storage_path_key UNIQUE (storage_path);
alter table public.action_plans add constraint action_plans_progress_check CHECK (progress >= 0 AND progress <= 100);
alter table public.action_plans add constraint action_plans_steps_check CHECK (jsonb_typeof(steps) = 'array'::text AND pg_column_size(steps) <= 65536);
alter table public.action_plans add constraint action_plans_title_check CHECK (char_length(title) >= 2 AND char_length(title) <= 160);
alter table public.advisor_links add constraint advisor_links_check CHECK (beneficiary_id <> professional_id);
alter table public.advisor_links add constraint advisor_links_check1 CHECK (status <> 'actif'::public.link_status OR accepted_at IS NOT NULL AND cardinality(scopes) > 0);
alter table public.advisor_links add constraint advisor_links_check2 CHECK ((status <> ALL (ARRAY['refuse'::public.link_status, 'revoque'::public.link_status])) OR ended_at IS NOT NULL);
alter table public.advisor_links add constraint advisor_links_message_check CHECK (char_length(message) <= 500);
alter table public.advisor_links add constraint advisor_links_scopes_check CHECK (scopes <@ ARRAY['cv'::text, 'bilan'::text, 'projet'::text, 'candidatures'::text, 'progression'::text]);
alter table public.app_state add constraint app_state_device_label_check CHECK (char_length(device_label) <= 60);
alter table public.app_state add constraint app_state_schema_version_check CHECK (schema_version >= 1 AND schema_version <= 100);
alter table public.app_state add constraint app_state_state_check CHECK (jsonb_typeof(state) = 'object'::text AND pg_column_size(state) <= 2097152);
alter table public.app_state add constraint app_state_version_check CHECK (version >= 1);
alter table public.app_state_snapshots add constraint app_state_snapshots_reason_check CHECK (reason = ANY (ARRAY['avant_import'::text, 'conflit'::text, 'avant_restauration'::text, 'manuel'::text]));
alter table public.app_state_snapshots add constraint app_state_snapshots_state_check CHECK (jsonb_typeof(state) = 'object'::text);
alter table public.application_events add constraint application_events_detail_check CHECK (char_length(detail) <= 2000);
alter table public.application_events add constraint application_events_kind_check CHECK (kind = ANY (ARRAY['envoi'::text, 'relance'::text, 'reponse'::text, 'entretien'::text, 'note'::text, 'statut'::text]));
alter table public.applications add constraint applications_cover_letter_check CHECK (char_length(cover_letter) <= 10000);
alter table public.applications add constraint applications_followup_every_days_check CHECK (followup_every_days >= 3 AND followup_every_days <= 30);
alter table public.applications add constraint applications_followup_max_check CHECK (followup_max >= 0 AND followup_max <= 5);
alter table public.applications add constraint applications_offer_check CHECK (jsonb_typeof(offer) = 'object'::text AND offer ? 'titre'::text AND pg_column_size(offer) <= 16384);
alter table public.applications add constraint review_before_send CHECK (sent_at IS NULL OR reviewed_at IS NOT NULL AND reviewed_at <= sent_at);
alter table public.applications add constraint sent_status_has_date CHECK ((status <> ALL (ARRAY['envoyee'::public.application_status, 'relancee'::public.application_status])) OR sent_at IS NOT NULL);
alter table public.assessment_reports add constraint assessment_reports_content_check CHECK (jsonb_typeof(content) = 'object'::text AND pg_column_size(content) <= 131072);
alter table public.assessment_reports add constraint assessment_reports_source_check CHECK (source = ANY (ARRAY['restitution'::text, 'portrait'::text]));
alter table public.assessments add constraint assessments_answers_check CHECK ((jsonb_typeof(answers) = ANY (ARRAY['object'::text, 'array'::text])) AND pg_column_size(answers) <= 65536);
alter table public.assessments add constraint assessments_check CHECK (completed_at IS NULL OR completed_at >= started_at);
alter table public.assessments add constraint assessments_check1 CHECK (completed_at IS NULL OR result IS NOT NULL);
alter table public.assessments add constraint assessments_result_check CHECK (result IS NULL OR jsonb_typeof(result) = 'object'::text AND pg_column_size(result) <= 65536);
alter table public.assessments add constraint assessments_test_code_check CHECK (test_code ~ '^[a-z0-9_]{2,32}$'::text);
alter table public.audit_events add constraint audit_events_action_check CHECK (action ~ '^[a-z_]+(\.[a-z_]+)*$'::text AND char_length(action) <= 64);
alter table public.audit_events add constraint audit_events_detail_check CHECK (jsonb_typeof(detail) = 'object'::text AND pg_column_size(detail) <= 4096);
alter table public.audit_events add constraint audit_events_target_id_check CHECK (char_length(target_id) <= 128);
alter table public.audit_events add constraint audit_events_target_table_check CHECK (char_length(target_table) <= 64);
alter table public.biz_forecasts add constraint biz_forecasts_data_check CHECK (jsonb_typeof(data) = 'object'::text AND pg_column_size(data) <= 131072);
alter table public.biz_projects add constraint biz_projects_legal_status_check CHECK (char_length(legal_status) <= 40);
alter table public.biz_projects add constraint biz_projects_name_check CHECK (char_length(name) <= 120);
alter table public.biz_projects add constraint biz_projects_progress_check CHECK (progress >= 0 AND progress <= 100);
alter table public.biz_projects add constraint biz_projects_project_check CHECK (jsonb_typeof(project) = 'object'::text AND pg_column_size(project) <= 65536);
alter table public.biz_projects add constraint biz_projects_touched_fields_check CHECK (cardinality(touched_fields) <= 300);
alter table public.biz_projects add constraint biz_projects_validation_check CHECK (jsonb_typeof(validation) = 'object'::text AND pg_column_size(validation) <= 65536);
alter table public.career_tracks add constraint career_tracks_job_title_check CHECK (char_length(job_title) >= 2 AND char_length(job_title) <= 120);
alter table public.career_tracks add constraint career_tracks_reason_check CHECK (char_length(reason) <= 500);
alter table public.career_tracks add constraint career_tracks_source_check CHECK (source = ANY (ARRAY['bilan'::text, 'manuel'::text, 'conseiller'::text]));
alter table public.consents add constraint consents_check CHECK (withdrawn_at IS NULL OR withdrawn_at >= granted_at);
alter table public.consents add constraint consents_text_version_check CHECK (char_length(text_version) >= 1 AND char_length(text_version) <= 20);
alter table public.cv_profiles add constraint cv_profiles_extracted_check CHECK (jsonb_typeof(extracted) = 'object'::text AND pg_column_size(extracted) <= 65536);
alter table public.cv_profiles add constraint cv_profiles_raw_text_check CHECK (char_length(raw_text) <= 60000);
alter table public.cv_profiles add constraint cv_profiles_title_check CHECK (char_length(title) <= 120);
alter table public.documents add constraint documents_check CHECK (split_part(storage_path, '/'::text, 1) = user_id::text);
alter table public.documents add constraint documents_filename_check CHECK (char_length(filename) >= 1 AND char_length(filename) <= 200);
alter table public.documents add constraint documents_mime_type_check CHECK (mime_type = ANY (ARRAY['application/pdf'::text, 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'::text, 'image/jpeg'::text, 'image/png'::text, 'video/mp4'::text, 'video/webm'::text, 'video/quicktime'::text, 'text/plain'::text]));
alter table public.documents add constraint documents_sha256_check CHECK (sha256 ~ '^[0-9a-f]{64}$'::text);
alter table public.documents add constraint documents_size_bytes_check CHECK (size_bytes >= 1 AND size_bytes <= 52428800);
alter table public.documents add constraint documents_storage_path_check CHECK (split_part(storage_path, '/'::text, 1) ~ '^[0-9a-f-]{36}$'::text AND POSITION(('..'::text) IN (storage_path)) = 0 AND char_length(storage_path) <= 300);
alter table public.interview_preps add constraint interview_preps_notes_check CHECK (char_length(notes) <= 10000);
alter table public.interview_preps add constraint interview_preps_questions_check CHECK (jsonb_typeof(questions) = 'array'::text AND pg_column_size(questions) <= 65536);
alter table public.organization_members add constraint organization_members_member_role_check CHECK (member_role = ANY (ARRAY['conseiller'::text, 'responsable'::text]));
alter table public.organizations add constraint organizations_kind_check CHECK (kind = ANY (ARRAY['mission_locale'::text, 'france_travail'::text, 'cabinet'::text, 'association'::text, 'collectivite'::text, 'autre'::text]));
alter table public.organizations add constraint organizations_name_check CHECK (char_length(name) >= 2 AND char_length(name) <= 120);
alter table public.organizations add constraint organizations_siret_check CHECK (siret ~ '^[0-9]{14}$'::text);
alter table public.profiles add constraint profiles_display_name_check CHECK (char_length(display_name) >= 1 AND char_length(display_name) <= 80);
alter table public.profiles add constraint profiles_locale_check CHECK (locale = ANY (ARRAY['fr'::text, 'en'::text, 'es'::text, 'ar'::text]));
alter table public.profiles add constraint profiles_preferences_check CHECK (jsonb_typeof(preferences) = 'object'::text AND pg_column_size(preferences) <= 8192);
alter table public.progress_steps add constraint progress_steps_path_check CHECK (path = ANY (ARRAY['emploi'::text, 'jeunes'::text, 'orientation'::text, 'creation'::text, 'outils'::text, 'competences'::text]));
alter table public.progress_steps add constraint progress_steps_step_check CHECK (step ~ '^[a-z0-9_-]{1,40}$'::text);
alter table public.recommendations add constraint recommendations_body_check CHECK (char_length(body) <= 2000);
alter table public.recommendations add constraint recommendations_kind_check CHECK (kind = ANY (ARRAY['offre'::text, 'formation'::text, 'piste'::text, 'conseil'::text]));
alter table public.recommendations add constraint recommendations_title_check CHECK (char_length(title) >= 2 AND char_length(title) <= 160);
alter table public.recommendations add constraint recommendations_url_check CHECK (url ~ '^https://'::text AND char_length(url) <= 500);
alter table public.video_cvs add constraint video_cvs_analysis_check CHECK (analysis IS NULL OR jsonb_typeof(analysis) = 'object'::text AND pg_column_size(analysis) <= 32768);
alter table public.video_cvs add constraint video_cvs_external_url_check CHECK (external_url ~ '^https://'::text AND char_length(external_url) <= 500);
alter table public.video_cvs add constraint video_cvs_script_check CHECK (char_length(script) <= 5000);
alter table public.video_cvs add constraint video_cvs_target_role_check CHECK (char_length(target_role) <= 120);
alter table public.action_plans add constraint action_plans_track_id_user_id_fkey FOREIGN KEY (track_id, user_id) REFERENCES public.career_tracks(id, user_id) ON DELETE SET NULL (track_id);
alter table public.action_plans add constraint action_plans_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;
alter table public.advisor_links add constraint advisor_links_beneficiary_id_fkey FOREIGN KEY (beneficiary_id) REFERENCES public.profiles(id) ON DELETE CASCADE;
alter table public.advisor_links add constraint advisor_links_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id) ON DELETE SET NULL;
alter table public.advisor_links add constraint advisor_links_professional_id_fkey FOREIGN KEY (professional_id) REFERENCES public.profiles(id) ON DELETE CASCADE;
alter table public.app_state add constraint app_state_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;
alter table public.app_state_snapshots add constraint app_state_snapshots_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;
alter table public.application_events add constraint application_events_application_id_user_id_fkey FOREIGN KEY (application_id, user_id) REFERENCES public.applications(id, user_id) ON DELETE CASCADE;
alter table public.applications add constraint applications_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;
alter table public.assessment_reports add constraint assessment_reports_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;
alter table public.assessments add constraint assessments_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;
alter table public.biz_forecasts add constraint biz_forecasts_project_id_user_id_fkey FOREIGN KEY (project_id, user_id) REFERENCES public.biz_projects(id, user_id) ON DELETE CASCADE;
alter table public.biz_projects add constraint biz_projects_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;
alter table public.career_tracks add constraint career_tracks_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;
alter table public.consents add constraint consents_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;
alter table public.cv_profiles add constraint cv_profiles_document_id_user_id_fkey FOREIGN KEY (document_id, user_id) REFERENCES public.documents(id, user_id) ON DELETE SET NULL (document_id);
alter table public.cv_profiles add constraint cv_profiles_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;
alter table public.documents add constraint documents_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;
alter table public.interview_preps add constraint interview_preps_application_id_user_id_fkey FOREIGN KEY (application_id, user_id) REFERENCES public.applications(id, user_id) ON DELETE CASCADE;
alter table public.organization_members add constraint organization_members_added_by_fkey FOREIGN KEY (added_by) REFERENCES public.profiles(id) ON DELETE SET NULL;
alter table public.organization_members add constraint organization_members_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id) ON DELETE CASCADE;
alter table public.organization_members add constraint organization_members_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;
alter table public.profiles add constraint profiles_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;
alter table public.progress_steps add constraint progress_steps_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;
alter table public.recommendations add constraint recommendations_beneficiary_id_fkey FOREIGN KEY (beneficiary_id) REFERENCES public.profiles(id) ON DELETE CASCADE;
alter table public.recommendations add constraint recommendations_professional_id_fkey FOREIGN KEY (professional_id) REFERENCES public.profiles(id) ON DELETE SET NULL;
alter table public.user_roles add constraint user_roles_granted_by_fkey FOREIGN KEY (granted_by) REFERENCES public.profiles(id) ON DELETE SET NULL;
alter table public.user_roles add constraint user_roles_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;
alter table public.video_cvs add constraint video_cvs_document_id_user_id_fkey FOREIGN KEY (document_id, user_id) REFERENCES public.documents(id, user_id) ON DELETE SET NULL (document_id);
alter table public.video_cvs add constraint video_cvs_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;

-- ============ Index ============
CREATE INDEX action_plans_user_idx ON public.action_plans USING btree (user_id, updated_at DESC);
CREATE INDEX advisor_links_benef_idx ON public.advisor_links USING btree (beneficiary_id, status);
CREATE UNIQUE INDEX advisor_links_open_uniq ON public.advisor_links USING btree (beneficiary_id, professional_id) WHERE (status = ANY (ARRAY['demande'::public.link_status, 'actif'::public.link_status]));
CREATE INDEX advisor_links_pro_idx ON public.advisor_links USING btree (professional_id, status);
CREATE INDEX app_state_snapshots_user_idx ON public.app_state_snapshots USING btree (user_id, created_at DESC);
CREATE INDEX application_events_app_idx ON public.application_events USING btree (application_id, occurred_at);
CREATE INDEX applications_followup_idx ON public.applications USING btree (next_followup_at) WHERE (auto_followup AND (next_followup_at IS NOT NULL));
CREATE INDEX applications_user_idx ON public.applications USING btree (user_id, status, updated_at DESC);
CREATE INDEX assessment_reports_user_idx ON public.assessment_reports USING btree (user_id, created_at DESC);
CREATE INDEX assessments_user_idx ON public.assessments USING btree (user_id, test_code, completed_at DESC);
CREATE INDEX audit_events_actor_idx ON public.audit_events USING btree (actor_id, occurred_at DESC);
CREATE INDEX audit_events_time_idx ON public.audit_events USING btree (occurred_at DESC);
CREATE INDEX biz_forecasts_user_idx ON public.biz_forecasts USING btree (user_id);
CREATE INDEX biz_projects_user_idx ON public.biz_projects USING btree (user_id, updated_at DESC);
CREATE UNIQUE INDEX career_tracks_title_uniq ON public.career_tracks USING btree (user_id, lower(job_title));
CREATE INDEX consents_user_purpose_idx ON public.consents USING btree (user_id, purpose, granted_at DESC);
CREATE UNIQUE INDEX cv_profiles_one_current ON public.cv_profiles USING btree (user_id) WHERE is_current;
CREATE INDEX cv_profiles_user_idx ON public.cv_profiles USING btree (user_id, created_at DESC);
CREATE INDEX documents_user_idx ON public.documents USING btree (user_id, kind, created_at DESC);
CREATE INDEX interview_preps_app_idx ON public.interview_preps USING btree (application_id);
CREATE INDEX organization_members_user_idx ON public.organization_members USING btree (user_id);
CREATE INDEX recommendations_benef_idx ON public.recommendations USING btree (beneficiary_id, created_at DESC);
CREATE INDEX recommendations_pro_idx ON public.recommendations USING btree (professional_id, created_at DESC);
CREATE INDEX user_roles_role_idx ON public.user_roles USING btree (role);

