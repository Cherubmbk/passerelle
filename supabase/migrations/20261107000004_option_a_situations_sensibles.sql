-- Option A (données sensibles) : la RQTH, le RSA et l'arrivée récente en France restent sur l'appareil.
-- Le site ne les envoie pas ; par sécurité, la base les retire aussi si elles arrivaient quand même.
create or replace function private.clean_state(p_state jsonb)
 returns jsonb language sql immutable set search_path to ''
as $function$
  select case when jsonb_typeof(s -> 'situation') = 'array'
    then jsonb_set(s, '{situation}', coalesce((
      select jsonb_agg(x) from jsonb_array_elements(s -> 'situation') x
      where (x #>> '{}') not in ('Reconnaissance travailleur handicapé (RQTH)', 'Bénéficiaire du RSA', 'Arrivé(e) récemment en France')), '[]'::jsonb))
    else s end
  from (select (p_state #- '{user,type}') #- '{user,email}' as s) t
$function$;
revoke all on function private.clean_state(jsonb) from public, anon, authenticated;
