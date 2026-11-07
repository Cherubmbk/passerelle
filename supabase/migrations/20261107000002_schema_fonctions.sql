-- Passerelle · structure initiale de la base (copie fidèle du projet d'origine, 7 novembre 2026)
-- Partie 2 : fonctions et droits d'exécution

-- ============ Fonctions internes (schéma private) ============
CREATE OR REPLACE FUNCTION private.set_updated_at()
 RETURNS trigger LANGUAGE plpgsql SET search_path TO ''
AS $function$
begin
  new.updated_at := now();
  return new;
end $function$;

CREATE OR REPLACE FUNCTION private.log_audit(p_action text, p_table text, p_target text, p_detail jsonb DEFAULT '{}'::jsonb)
 RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
begin
  insert into public.audit_events (actor_id, action, target_table, target_id, detail)
  values (auth.uid(), p_action, p_table, p_target, coalesce(p_detail, '{}'::jsonb));
end $function$;

CREATE OR REPLACE FUNCTION private.has_role(p_role public.app_role)
 RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO ''
AS $function$
  select exists (select 1 from public.user_roles where user_id = auth.uid() and role = p_role)
$function$;

CREATE OR REPLACE FUNCTION private.has_consent(p_user uuid, p_purpose public.consent_purpose)
 RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO ''
AS $function$
  select exists (select 1 from public.consents where user_id = p_user and purpose = p_purpose and withdrawn_at is null)
$function$;

CREATE OR REPLACE FUNCTION private.can_view(p_owner uuid, p_scope text)
 RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO ''
AS $function$
  select p_owner = auth.uid()
      or (p_scope is not null
          and exists (select 1 from public.user_roles r where r.user_id = auth.uid() and r.role = 'conseiller')
          and exists (select 1 from public.advisor_links l
                      where l.beneficiary_id = p_owner and l.professional_id = auth.uid()
                        and l.status = 'actif' and p_scope = any (l.scopes)))
$function$;

CREATE OR REPLACE FUNCTION private.is_linked(p_owner uuid)
 RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO ''
AS $function$
  select exists (select 1 from public.advisor_links l
                 where l.beneficiary_id = p_owner and l.professional_id = auth.uid() and l.status = 'actif')
     and exists (select 1 from public.user_roles r where r.user_id = auth.uid() and r.role = 'conseiller')
$function$;

CREATE OR REPLACE FUNCTION private.document_scope(p_kind public.document_kind)
 RETURNS text LANGUAGE sql IMMUTABLE SET search_path TO ''
AS $function$
  select case p_kind when 'cv' then 'cv' when 'lettre' then 'cv' when 'cv_video' then 'cv'
                     when 'business_plan' then 'projet' else null end
$function$;

CREATE OR REPLACE FUNCTION private.clean_state(p_state jsonb)
 RETURNS jsonb LANGUAGE sql IMMUTABLE SET search_path TO ''
AS $function$
  select (p_state #- '{user,type}') #- '{user,email}'
$function$;

CREATE OR REPLACE FUNCTION private.keep_snapshots(p_user uuid, p_keep integer DEFAULT 20)
 RETURNS void LANGUAGE sql SECURITY DEFINER SET search_path TO ''
AS $function$
  delete from public.app_state_snapshots
  where user_id = p_user
    and id not in (select id from public.app_state_snapshots where user_id = p_user order by created_at desc limit p_keep)
$function$;

CREATE OR REPLACE FUNCTION private.purge_audit(p_older_than interval)
 RETURNS bigint LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
declare n bigint;
begin
  perform set_config('passerelle.audit_purge', 'on', true);
  delete from public.audit_events where occurred_at < now() - p_older_than;
  get diagnostics n = row_count;
  perform set_config('passerelle.audit_purge', 'off', true);
  return n;
end $function$;

CREATE OR REPLACE FUNCTION private.audit_immutable()
 RETURNS trigger LANGUAGE plpgsql SET search_path TO ''
AS $function$
begin
  if tg_op = 'DELETE' and current_setting('passerelle.audit_purge', true) = 'on' then
    return old;
  end if;
  raise exception 'Le journal d''audit ne peut pas être modifié' using errcode = '42501';
end $function$;

CREATE OR REPLACE FUNCTION private.handle_new_user()
 RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
begin
  insert into public.profiles (id, display_name)
  values (new.id, nullif(left(btrim(coalesce(new.raw_user_meta_data ->> 'display_name', '')), 80), ''));
  return new;
end $function$;

CREATE OR REPLACE FUNCTION private.consents_guard()
 RETURNS trigger LANGUAGE plpgsql SET search_path TO ''
AS $function$
begin
  if new.user_id <> old.user_id or new.purpose <> old.purpose or new.text_version <> old.text_version
     or new.granted_at <> old.granted_at or old.withdrawn_at is not null or new.withdrawn_at is null then
    raise exception 'Un consentement peut seulement être retiré' using errcode = '42501';
  end if;
  return new;
end $function$;

CREATE OR REPLACE FUNCTION private.recommendations_guard()
 RETURNS trigger LANGUAGE plpgsql SET search_path TO ''
AS $function$
begin
  if auth.uid() is null then return new; end if;
  if auth.uid() = old.beneficiary_id and new.read_at is not null
     and (new.professional_id, new.beneficiary_id, new.kind, new.title, new.body, new.url, new.created_at)
         is not distinct from (old.professional_id, old.beneficiary_id, old.kind, old.title, old.body, old.url, old.created_at) then
    return new;
  end if;
  raise exception 'Modification non autorisée' using errcode = '42501';
end $function$;

CREATE OR REPLACE FUNCTION private.video_cvs_consent()
 RETURNS trigger LANGUAGE plpgsql SET search_path TO ''
AS $function$
begin
  if new.document_id is not null and not private.has_consent(new.user_id, 'stockage_cv_video') then
    raise exception 'Accord requis pour conserver la vidéo sur le serveur' using errcode = '42501';
  end if;
  return new;
end $function$;

CREATE OR REPLACE FUNCTION private.advisor_links_guard()
 RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
declare uid uuid := auth.uid();
begin
  if uid is null then return new; end if;   -- opérations serveur (clé de service)

  if tg_op = 'INSERT' then
    if new.professional_id <> uid or not private.has_role('conseiller') then
      raise exception 'Seul un professionnel vérifié peut demander un lien' using errcode = '42501';
    end if;
    if new.organization_id is not null and not exists (
      select 1 from public.organization_members m where m.organization_id = new.organization_id and m.user_id = uid) then
      raise exception 'Vous n''appartenez pas à cette structure' using errcode = '42501';
    end if;
    new.status := 'demande'; new.scopes := '{}'; new.accepted_at := null; new.ended_at := null; new.created_at := now();
    perform private.log_audit('link.request', 'advisor_links', new.id::text, jsonb_build_object('beneficiary', new.beneficiary_id));
    return new;
  end if;

  if new.beneficiary_id <> old.beneficiary_id or new.professional_id <> old.professional_id
     or new.organization_id is distinct from old.organization_id or new.created_at <> old.created_at then
    raise exception 'Ces champs ne peuvent pas être modifiés' using errcode = '42501';
  end if;
  if old.status in ('refuse', 'revoque') then
    raise exception 'Ce lien est clos' using errcode = '42501';
  end if;

  if uid = old.beneficiary_id then
    if old.status = 'demande' and new.status = 'actif' then
      new.accepted_at := now();
    elsif old.status = 'demande' and new.status = 'refuse' then
      new.ended_at := now(); new.scopes := '{}';
    elsif old.status = 'actif' and new.status = 'revoque' then
      new.ended_at := now(); new.scopes := '{}';
    elsif old.status = 'actif' and new.status = 'actif' then
      new.accepted_at := old.accepted_at;   -- simple changement de périmètre
    else
      raise exception 'Changement de statut non autorisé' using errcode = '42501';
    end if;
  elsif uid = old.professional_id then
    if new.scopes <> old.scopes then
      raise exception 'Seul le bénéficiaire choisit ce qu''il partage' using errcode = '42501';
    end if;
    if new.status = 'revoque' and old.status in ('demande', 'actif') then
      new.ended_at := now(); new.scopes := '{}';
    else
      raise exception 'Changement de statut non autorisé' using errcode = '42501';
    end if;
  else
    raise exception 'Action non autorisée' using errcode = '42501';
  end if;

  perform private.log_audit('link.' || new.status::text, 'advisor_links', new.id::text,
    jsonb_build_object('scopes', new.scopes, 'by', case when uid = old.beneficiary_id then 'beneficiaire' else 'professionnel' end));
  return new;
end $function$;

-- ============ Fonctions appelables par le site (schéma public) ============
CREATE OR REPLACE FUNCTION public.my_roles()
 RETURNS public.app_role[] LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO ''
AS $function$
  select coalesce(array_agg(role order by role), '{}') from public.user_roles where user_id = auth.uid()
$function$;

CREATE OR REPLACE FUNCTION public.grant_role(p_user uuid, p_role public.app_role)
 RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
begin
  if not private.has_role('admin') then
    raise exception 'Réservé aux administrateurs' using errcode = '42501';
  end if;
  insert into public.user_roles (user_id, role, granted_by) values (p_user, p_role, auth.uid())
  on conflict (user_id, role) do nothing;
  perform private.log_audit('role.grant', 'user_roles', p_user::text, jsonb_build_object('role', p_role));
end $function$;

CREATE OR REPLACE FUNCTION public.revoke_role(p_user uuid, p_role public.app_role)
 RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
begin
  if not private.has_role('admin') then
    raise exception 'Réservé aux administrateurs' using errcode = '42501';
  end if;
  if p_role = 'admin' and (select count(*) from public.user_roles where role = 'admin') <= 1
     and exists (select 1 from public.user_roles where user_id = p_user and role = 'admin') then
    raise exception 'Impossible de retirer le dernier administrateur' using errcode = '42501';
  end if;
  delete from public.user_roles where user_id = p_user and role = p_role;
  perform private.log_audit('role.revoke', 'user_roles', p_user::text, jsonb_build_object('role', p_role));
end $function$;

CREATE OR REPLACE FUNCTION public.save_app_state(p_state jsonb, p_expected_version bigint, p_device text DEFAULT NULL::text)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
declare
  uid uuid := auth.uid();
  cur public.app_state%rowtype;
begin
  if uid is null then raise exception 'Connexion requise' using errcode = '42501'; end if;
  if p_state is null or jsonb_typeof(p_state) <> 'object' then raise exception 'État invalide' using errcode = '22023'; end if;

  select * into cur from public.app_state where user_id = uid for update;
  if not found then
    if coalesce(p_expected_version, 0) <> 0 then
      return jsonb_build_object('conflict', true, 'version', 0);
    end if;
    insert into public.app_state (user_id, state, device_label) values (uid, private.clean_state(p_state), left(p_device, 60));
    return jsonb_build_object('conflict', false, 'version', 1);
  end if;

  if cur.version <> coalesce(p_expected_version, -1) then
    return jsonb_build_object('conflict', true, 'version', cur.version, 'updated_at', cur.updated_at, 'device', cur.device_label);
  end if;

  -- Conserver une copie avant chaque remplacement, y compris une sauvegarde normale.
  insert into public.app_state_snapshots (user_id, state, version, reason)
  values (uid, cur.state, cur.version, 'manuel');

  update public.app_state set state = private.clean_state(p_state), version = cur.version + 1,
      device_label = left(p_device, 60), updated_at = now()
  where user_id = uid;

  perform private.keep_snapshots(uid);
  return jsonb_build_object('conflict', false, 'version', cur.version + 1);
end $function$;

CREATE OR REPLACE FUNCTION public.import_local_state(p_state jsonb, p_consent_version text, p_device text DEFAULT NULL::text)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
declare
  uid uuid := auth.uid();
  cur public.app_state%rowtype;
  archived bigint := null;
  newv bigint;
begin
  if uid is null then raise exception 'Connexion requise' using errcode = '42501'; end if;
  if p_state is null or jsonb_typeof(p_state) <> 'object' then raise exception 'État invalide' using errcode = '22023'; end if;
  if p_consent_version is null or char_length(p_consent_version) not between 1 and 20 then
    raise exception 'Accord explicite requis pour importer' using errcode = '42501';
  end if;

  insert into public.consents (user_id, purpose, text_version) values (uid, 'import_local', p_consent_version);

  select * into cur from public.app_state where user_id = uid for update;
  if found then
    insert into public.app_state_snapshots (user_id, state, version, reason) values (uid, cur.state, cur.version, 'avant_import');
    archived := cur.version;
    update public.app_state set state = private.clean_state(p_state), version = cur.version + 1, device_label = left(p_device, 60)
    where user_id = uid;
    newv := cur.version + 1;
    perform private.keep_snapshots(uid);
  else
    insert into public.app_state (user_id, state, device_label) values (uid, private.clean_state(p_state), left(p_device, 60));
    newv := 1;
  end if;

  perform private.log_audit('state.import', 'app_state', uid::text,
    jsonb_build_object('version', newv, 'archived_version', archived, 'bytes', pg_column_size(p_state)));
  return jsonb_build_object('version', newv, 'archived_version', archived);
end $function$;

CREATE OR REPLACE FUNCTION public.restore_app_state(p_snapshot uuid)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
declare
  uid uuid := auth.uid();
  snap public.app_state_snapshots%rowtype;
  cur public.app_state%rowtype;
begin
  if uid is null then raise exception 'Connexion requise' using errcode = '42501'; end if;
  select * into snap from public.app_state_snapshots where id = p_snapshot and user_id = uid;
  if not found then raise exception 'Copie introuvable' using errcode = 'P0002'; end if;
  select * into cur from public.app_state where user_id = uid for update;
  if found then
    insert into public.app_state_snapshots (user_id, state, version, reason) values (uid, cur.state, cur.version, 'avant_restauration');
    update public.app_state set state = snap.state, version = cur.version + 1 where user_id = uid;
    perform private.keep_snapshots(uid);
    return jsonb_build_object('version', cur.version + 1);
  end if;
  insert into public.app_state (user_id, state) values (uid, snap.state);
  return jsonb_build_object('version', 1);
end $function$;

CREATE OR REPLACE FUNCTION public.export_my_data()
 RETURNS jsonb LANGUAGE plpgsql STABLE SET search_path TO ''
AS $function$
declare uid uuid := auth.uid();
begin
  if uid is null then raise exception 'Connexion requise' using errcode = '42501'; end if;
  return jsonb_build_object(
    'exported_at', now(),
    'profile',      (select to_jsonb(p) from public.profiles p where p.id = uid),
    'roles',        (select coalesce(jsonb_agg(r.role), '[]') from public.user_roles r where r.user_id = uid),
    'consents',     (select coalesce(jsonb_agg(c), '[]') from public.consents c where c.user_id = uid),
    'app_state',    (select to_jsonb(s) from public.app_state s where s.user_id = uid),
    'documents',    (select coalesce(jsonb_agg(d), '[]') from public.documents d where d.user_id = uid),
    'cv_profiles',  (select coalesce(jsonb_agg(x), '[]') from public.cv_profiles x where x.user_id = uid),
    'video_cv',     (select to_jsonb(x) from public.video_cvs x where x.user_id = uid),
    'assessments',  (select coalesce(jsonb_agg(x), '[]') from public.assessments x where x.user_id = uid),
    'reports',      (select coalesce(jsonb_agg(x), '[]') from public.assessment_reports x where x.user_id = uid),
    'career_tracks',(select coalesce(jsonb_agg(x), '[]') from public.career_tracks x where x.user_id = uid),
    'action_plans', (select coalesce(jsonb_agg(x), '[]') from public.action_plans x where x.user_id = uid),
    'progress',     (select coalesce(jsonb_agg(x), '[]') from public.progress_steps x where x.user_id = uid),
    'biz_projects', (select coalesce(jsonb_agg(x), '[]') from public.biz_projects x where x.user_id = uid),
    'biz_forecasts',(select coalesce(jsonb_agg(x), '[]') from public.biz_forecasts x where x.user_id = uid),
    'applications', (select coalesce(jsonb_agg(x), '[]') from public.applications x where x.user_id = uid),
    'application_events', (select coalesce(jsonb_agg(x), '[]') from public.application_events x where x.user_id = uid),
    'interview_preps',    (select coalesce(jsonb_agg(x), '[]') from public.interview_preps x where x.user_id = uid),
    'recommendations_received', (select coalesce(jsonb_agg(x), '[]') from public.recommendations x where x.beneficiary_id = uid),
    'advisor_links', (select coalesce(jsonb_agg(x), '[]') from public.advisor_links x where x.beneficiary_id = uid or x.professional_id = uid));
end $function$;

-- Droits d'exécution (identiques au projet d'origine)
revoke all on function private.keep_snapshots(uuid, integer) from public, anon, authenticated;
revoke all on function private.clean_state(jsonb) from public, anon, authenticated;
revoke all on function private.purge_audit(interval) from public, anon, authenticated;
grant execute on function private.purge_audit(interval) to service_role;
revoke all on function private.has_role(public.app_role) from public, anon;
revoke all on function private.has_consent(uuid, public.consent_purpose) from public, anon;
revoke all on function private.can_view(uuid, text) from public, anon;
revoke all on function private.is_linked(uuid) from public, anon;
revoke all on function private.log_audit(text, text, text, jsonb) from public, anon;
grant execute on function private.has_role(public.app_role), private.has_consent(uuid, public.consent_purpose),
  private.can_view(uuid, text), private.is_linked(uuid), private.log_audit(text, text, text, jsonb),
  private.document_scope(public.document_kind) to authenticated, service_role;
revoke all on function public.my_roles(), public.grant_role(uuid, public.app_role), public.revoke_role(uuid, public.app_role),
  public.save_app_state(jsonb, bigint, text), public.import_local_state(jsonb, text, text), public.restore_app_state(uuid),
  public.export_my_data() from public, anon;
grant execute on function public.my_roles(), public.grant_role(uuid, public.app_role), public.revoke_role(uuid, public.app_role),
  public.save_app_state(jsonb, bigint, text), public.import_local_state(jsonb, text, text), public.restore_app_state(uuid),
  public.export_my_data() to authenticated, service_role;

