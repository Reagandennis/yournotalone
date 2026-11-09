-- 0029: Identity checks (KYC) before a therapist is approved.
--
-- Until now an application was typed-in details only. Now an applicant also
-- gives their date of birth, phone, ID and licence expiry, and uploads three
-- documents to the private therapist-kyc bucket under <user id>/:
--
--   id_front_path   the front of their ID or passport photo page
--   id_back_path    the back of a national ID (optional for passports)
--   selfie_path     a photo of them holding that ID next to their face
--   licence_path    their licence or current practising certificate
--
-- Nobody but the applicant (upload only) and admins (to look) can touch those
-- files. An admin can approve only after ticking every check in
-- kyc_check_keys(), and who ticked them, and when, is kept with the
-- application. The licence expiry date is copied to the therapist so it can
-- be watched after approval.
--
-- Paste-run this in the Supabase dashboard → SQL Editor after 0028. Safe to
-- re-run.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'therapist-kyc',
  'therapist-kyc',
  false,
  10485760,
  array['image/jpeg', 'image/png', 'image/webp', 'application/pdf']
)
on conflict (id) do update
set public = false,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

-- Applicants add files to their own folder; they can't list, read, replace
-- or delete them afterwards (a new upload gets a new name instead).
drop policy if exists "Applicants upload their own KYC documents" on storage.objects;
create policy "Applicants upload their own KYC documents"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'therapist-kyc'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

drop policy if exists "Admins read KYC documents" on storage.objects;
create policy "Admins read KYC documents"
  on storage.objects for select to authenticated
  using (bucket_id = 'therapist-kyc' and (select public.is_admin()));

drop policy if exists "Admins delete KYC documents" on storage.objects;
create policy "Admins delete KYC documents"
  on storage.objects for delete to authenticated
  using (bucket_id = 'therapist-kyc' and (select public.is_admin()));

alter table public.therapist_applications
  add column if not exists date_of_birth date,
  add column if not exists phone text check (phone ~ '^\+[0-9]{7,15}$'),
  add column if not exists id_type text
    check (id_type in ('national_id', 'passport', 'alien_id', 'driving_licence')),
  add column if not exists id_number text check (length(trim(id_number)) between 3 and 40),
  add column if not exists licence_expires_on date,
  add column if not exists id_front_path text,
  add column if not exists id_back_path text,
  add column if not exists selfie_path text,
  add column if not exists licence_path text,
  add column if not exists kyc_checks jsonb not null default '{}',
  add column if not exists kyc_confirmed_at timestamptz;

alter table public.therapists
  add column if not exists licence_expires_on date;

-- What an admin must confirm, in order. Keep in step with KYC_CHECKS on the
-- admin page.
create or replace function public.kyc_check_keys()
returns text[]
language sql
immutable
set search_path = ''
as $$
  select array['id_genuine', 'id_matches', 'selfie_matches', 'licence_on_register', 'licence_current'];
$$;

-- A document is acceptable only if this person uploaded it to their own
-- folder of the KYC bucket, and it's really there.
create or replace function public.kyc_file_ok(p_path text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select p_path is not null
    and length(p_path) <= 300
    and p_path ~ ('^' || auth.uid()::text || '/[A-Za-z0-9_.-]+$')
    and exists (
      select 1 from storage.objects o
      where o.bucket_id = 'therapist-kyc' and o.name = p_path
    );
$$;

create or replace function public.therapist_portal_status()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  me uuid := public.current_therapist_id();
  result jsonb;
begin
  if auth.uid() is null then
    raise exception 'Sign in first.' using errcode = '42501';
  end if;
  select jsonb_build_object(
    'email', public.current_user_email(),
    'is_admin', public.is_admin(),
    'therapist', (
      select jsonb_build_object(
        'id', t.id, 'full_name', t.full_name, 'title', t.title,
        'credentials', t.credentials, 'bio', t.bio,
        'specialties', t.specialties, 'languages', t.languages,
        'years_experience', t.years_experience, 'photo_url', t.photo_url,
        'active', t.active, 'licence_expires_on', t.licence_expires_on
      )
      from public.therapists t where t.id = me
    ),
    'application', (
      select jsonb_build_object(
        'id', a.id, 'status', a.status, 'full_name', a.full_name,
        'title', a.title, 'credentials', a.credentials,
        'licence_number', a.licence_number, 'licence_body', a.licence_body,
        'country', a.country, 'bio', a.bio, 'specialties', a.specialties,
        'languages', a.languages, 'years_experience', a.years_experience,
        'photo_url', a.photo_url, 'decline_reason', a.decline_reason,
        'date_of_birth', a.date_of_birth, 'phone', a.phone,
        'id_type', a.id_type, 'id_number', a.id_number,
        'licence_expires_on', a.licence_expires_on,
        'id_front_path', a.id_front_path, 'id_back_path', a.id_back_path,
        'selfie_path', a.selfie_path, 'licence_path', a.licence_path,
        'created_at', a.created_at, 'updated_at', a.updated_at
      )
      from public.therapist_applications a where a.user_id = auth.uid()
    )
  ) into result;
  return result;
end;
$$;

drop function if exists public.therapist_submit_application(text, text, text, text, text, text, text, text[], text[], integer, text);

-- Sends, or after a decline re-sends, the signed-in person's application,
-- with their identity details and documents.
create or replace function public.therapist_submit_application(
  p_full_name text,
  p_title text,
  p_credentials text,
  p_licence_number text,
  p_licence_body text,
  p_country text,
  p_bio text,
  p_specialties text[],
  p_languages text[],
  p_years_experience integer,
  p_photo_url text,
  p_date_of_birth date,
  p_phone text,
  p_id_type text,
  p_id_number text,
  p_licence_expires_on date,
  p_id_front_path text,
  p_id_back_path text,
  p_selfie_path text,
  p_licence_path text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  care_team constant text := 'reagan.e.owiti@gmail.com';
  v_email text := public.current_user_email();
  v_id uuid;
  v_name text := trim(coalesce(p_full_name, ''));
  v_photo text := nullif(trim(coalesce(p_photo_url, '')), '');
  v_phone text := regexp_replace(coalesce(p_phone, ''), '[\s().-]', '', 'g');
  v_back text := nullif(trim(coalesce(p_id_back_path, '')), '');
begin
  if auth.uid() is null or v_email is null then
    raise exception 'Confirm your email address before applying.' using errcode = '42501';
  end if;
  if public.current_therapist_id() is not null then
    raise exception 'You’re already on the care team.' using errcode = '22023';
  end if;
  if exists (select 1 from public.therapist_applications a
             where a.user_id = auth.uid() and a.status = 'approved') then
    raise exception 'Your application has already been approved.' using errcode = '22023';
  end if;
  if length(v_name) < 2 then
    raise exception 'Enter your full name.' using errcode = '22023';
  end if;
  if length(trim(coalesce(p_credentials, ''))) < 2 then
    raise exception 'Enter your qualifications.' using errcode = '22023';
  end if;
  if length(trim(coalesce(p_licence_number, ''))) < 2
     or length(trim(coalesce(p_licence_body, ''))) < 2 then
    raise exception 'Enter your licence number and the body that issued it.' using errcode = '22023';
  end if;
  if length(trim(coalesce(p_country, ''))) < 2 then
    raise exception 'Enter the country you’re licensed in.' using errcode = '22023';
  end if;
  if p_years_experience is not null and p_years_experience not between 0 and 70 then
    raise exception 'Years of experience should be between 0 and 70.' using errcode = '22023';
  end if;
  if not public.therapist_photo_ok(v_photo) then
    raise exception 'Upload your photo from this page.' using errcode = '22023';
  end if;
  if p_date_of_birth is null
     or p_date_of_birth > (current_date - interval '21 years')::date
     or p_date_of_birth < (current_date - interval '100 years')::date then
    raise exception 'Enter your date of birth. You need to be 21 or over to apply.' using errcode = '22023';
  end if;
  if v_phone !~ '^\+[0-9]{7,15}$' then
    raise exception 'Enter your phone number with the country code, like +254 712 345 678.' using errcode = '22023';
  end if;
  if p_id_type is null or p_id_type not in ('national_id', 'passport', 'alien_id', 'driving_licence') then
    raise exception 'Choose the kind of ID you’re using.' using errcode = '22023';
  end if;
  if length(trim(coalesce(p_id_number, ''))) not between 3 and 40 then
    raise exception 'Enter the number on your ID.' using errcode = '22023';
  end if;
  if p_licence_expires_on is null or p_licence_expires_on <= current_date then
    raise exception 'Enter when your licence or practising certificate expires. It needs to be current.' using errcode = '22023';
  end if;
  if not public.kyc_file_ok(p_id_front_path) then
    raise exception 'Upload a photo of your ID.' using errcode = '22023';
  end if;
  if p_id_type <> 'passport' and not public.kyc_file_ok(v_back) then
    raise exception 'Upload a photo of the back of your ID.' using errcode = '22023';
  end if;
  if v_back is not null and not public.kyc_file_ok(v_back) then
    raise exception 'Upload the back of your ID from this page.' using errcode = '22023';
  end if;
  if not public.kyc_file_ok(p_selfie_path) then
    raise exception 'Upload a photo of yourself holding your ID.' using errcode = '22023';
  end if;
  if not public.kyc_file_ok(p_licence_path) then
    raise exception 'Upload your licence or practising certificate.' using errcode = '22023';
  end if;

  insert into public.therapist_applications as a (
    user_id, email, full_name, title, credentials, licence_number,
    licence_body, country, bio, specialties, languages, years_experience,
    photo_url, date_of_birth, phone, id_type, id_number, licence_expires_on,
    id_front_path, id_back_path, selfie_path, licence_path, kyc_confirmed_at
  )
  values (
    auth.uid(), v_email, v_name, nullif(trim(p_title), ''), trim(p_credentials),
    trim(p_licence_number), trim(p_licence_body), trim(p_country),
    nullif(trim(p_bio), ''), public.clean_tags(p_specialties, 12),
    public.clean_tags(p_languages, 10), p_years_experience, v_photo,
    p_date_of_birth, v_phone, p_id_type, upper(trim(p_id_number)),
    p_licence_expires_on, p_id_front_path, v_back, p_selfie_path,
    p_licence_path, now()
  )
  on conflict (user_id) do update
  set email = excluded.email,
      full_name = excluded.full_name,
      title = excluded.title,
      credentials = excluded.credentials,
      licence_number = excluded.licence_number,
      licence_body = excluded.licence_body,
      country = excluded.country,
      bio = excluded.bio,
      specialties = excluded.specialties,
      languages = excluded.languages,
      years_experience = excluded.years_experience,
      photo_url = excluded.photo_url,
      date_of_birth = excluded.date_of_birth,
      phone = excluded.phone,
      id_type = excluded.id_type,
      id_number = excluded.id_number,
      licence_expires_on = excluded.licence_expires_on,
      id_front_path = excluded.id_front_path,
      id_back_path = excluded.id_back_path,
      selfie_path = excluded.selfie_path,
      licence_path = excluded.licence_path,
      kyc_confirmed_at = excluded.kyc_confirmed_at,
      kyc_checks = '{}',
      status = 'pending',
      decline_reason = null,
      reviewed_by = null,
      reviewed_at = null,
      updated_at = now()
  returning a.id into v_id;

  perform public.send_app_email(
    care_team,
    v_email,
    'New therapist application: ' || v_name,
    public.email_layout(
      'A therapist has applied to join the care team.',
      'New therapist application',
      public.email_escape(v_name) || ' has applied to join the care team.',
      public.email_box('#F3F6FC', 'Licence',
        '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">'
        || public.email_row('Number', public.email_escape(trim(p_licence_number)))
        || public.email_row('Issued by', public.email_escape(trim(p_licence_body)))
        || public.email_row('Country', public.email_escape(trim(p_country)))
        || public.email_row('Expires', to_char(p_licence_expires_on, 'DD Mon YYYY'))
        || public.email_row('Email', public.email_escape(v_email))
        || '</table>'),
      'Their ID, selfie and licence are on the admin page, under Applications. '
        || 'Check each one, and the licence with the issuing body, before you approve.'
    ),
    v_name || ' has applied to join the care team.' || E'\n\n'
      || 'Licence: ' || trim(p_licence_number) || ', issued by ' || trim(p_licence_body)
      || ' (' || trim(p_country) || '), expires ' || to_char(p_licence_expires_on, 'DD Mon YYYY')
      || E'\n' || 'Email: ' || v_email || E'\n\n'
      || 'Their ID, selfie and licence are on the admin page, under Applications. '
      || 'Check each one, and the licence with the issuing body, before you approve.',
    'therapist-application/' || v_id || '/' || extract(epoch from now())::bigint
  );
  return v_id;
end;
$$;

drop function if exists public.admin_list_therapist_applications();

create or replace function public.admin_list_therapist_applications()
returns table (
  id uuid,
  email text,
  full_name text,
  title text,
  credentials text,
  licence_number text,
  licence_body text,
  country text,
  bio text,
  specialties text[],
  languages text[],
  years_experience smallint,
  photo_url text,
  status text,
  decline_reason text,
  therapist_id uuid,
  reviewed_by text,
  reviewed_at timestamptz,
  created_at timestamptz,
  updated_at timestamptz,
  date_of_birth date,
  phone text,
  id_type text,
  id_number text,
  licence_expires_on date,
  id_front_path text,
  id_back_path text,
  selfie_path text,
  licence_path text,
  kyc_checks jsonb
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not public.is_admin() then
    raise exception 'Admins only' using errcode = '42501';
  end if;
  return query
    select a.id, a.email, a.full_name, a.title, a.credentials, a.licence_number,
           a.licence_body, a.country, a.bio, a.specialties, a.languages,
           a.years_experience, a.photo_url, a.status, a.decline_reason,
           a.therapist_id, a.reviewed_by, a.reviewed_at, a.created_at, a.updated_at,
           a.date_of_birth, a.phone, a.id_type, a.id_number, a.licence_expires_on,
           a.id_front_path, a.id_back_path, a.selfie_path, a.licence_path,
           a.kyc_checks
    from public.therapist_applications a
    order by (a.status = 'pending') desc, a.updated_at desc
    limit 500;
end;
$$;

drop function if exists public.admin_review_therapist_application(uuid, boolean, text);

-- Approve: only with every KYC check ticked and the licence still current;
-- the application becomes a therapist profile and sign-in (the welcome email
-- goes from the therapist_accounts trigger). Decline: the applicant is told,
-- with the reason if there is one, and can apply again.
create or replace function public.admin_review_therapist_application(
  p_id uuid,
  p_approve boolean,
  p_reason text default null,
  p_checks text[] default '{}'
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  care_team constant text := 'reagan.e.owiti@gmail.com';
  app public.therapist_applications%rowtype;
  therapist uuid;
  v_reason text := nullif(trim(coalesce(p_reason, '')), '');
  v_missing text[];
  v_checks jsonb;
begin
  if not public.is_admin() then
    raise exception 'Admins only' using errcode = '42501';
  end if;
  select * into app from public.therapist_applications where id = p_id for update;
  if not found then
    raise exception 'That application no longer exists.' using errcode = 'P0002';
  end if;
  if app.status <> 'pending' then
    raise exception 'That application has already been reviewed.' using errcode = '22023';
  end if;

  select coalesce(jsonb_object_agg(k, jsonb_build_object(
           'by', public.current_user_email(), 'at', now())), '{}')
    into v_checks
    from unnest(public.kyc_check_keys()) k
    where k = any (coalesce(p_checks, '{}'));

  if coalesce(p_approve, false) then
    if app.kyc_confirmed_at is null or app.id_front_path is null
       or app.selfie_path is null or app.licence_path is null then
      raise exception 'This application has no identity documents. Decline it and ask them to send it again with their ID, selfie and licence.'
        using errcode = '22023';
    end if;
    select array_agg(k) into v_missing
      from unnest(public.kyc_check_keys()) k
      where not (k = any (coalesce(p_checks, '{}')));
    if v_missing is not null then
      raise exception 'Tick every check before you approve.' using errcode = '22023';
    end if;
    if app.licence_expires_on is null or app.licence_expires_on <= current_date then
      raise exception 'Their licence has expired. Decline and ask for a current practising certificate.'
        using errcode = '22023';
    end if;
    if exists (select 1 from public.therapist_accounts ta where ta.email = app.email) then
      raise exception 'A therapist already signs in with %. Link them on the Therapists page instead.', app.email
        using errcode = '23505';
    end if;
    insert into public.therapists (
      full_name, title, credentials, bio, specialties, languages,
      years_experience, photo_url, licence_expires_on, active
    )
    values (
      app.full_name, app.title,
      left(app.credentials || ' · Licence ' || app.licence_number || ' (' || app.licence_body || ')', 200),
      app.bio, app.specialties, app.languages, app.years_experience,
      app.photo_url, app.licence_expires_on, true
    )
    returning id into therapist;
    insert into public.therapist_accounts (therapist_id, email)
    values (therapist, app.email);
    update public.therapist_applications
    set status = 'approved', therapist_id = therapist, kyc_checks = v_checks,
        reviewed_by = public.current_user_email(), reviewed_at = now(),
        updated_at = now()
    where id = p_id;
    return therapist;
  end if;

  update public.therapist_applications
  set status = 'declined', decline_reason = v_reason, kyc_checks = v_checks,
      reviewed_by = public.current_user_email(), reviewed_at = now(),
      updated_at = now()
  where id = p_id;
  perform public.send_app_email(
    app.email,
    care_team,
    'About your application to the care team',
    public.email_layout(
      'An update on your application.',
      'About your application',
      'Hi ' || public.email_escape(split_part(app.full_name, ' ', 1))
        || ', thank you for applying to join the care team on Δεν είσαι μόνος. '
        || 'We can’t approve your application as it stands.',
      case when v_reason is null then '' else
        public.email_box('#F6F6F6', 'What we need',
          '<div style="font-size:12.5px;line-height:1.55;color:#6E6E73;">'
          || replace(public.email_escape(v_reason), E'\n', '<br>') || '</div>')
      end,
      'You can update your application and send it again at '
        || '<a href="https://therapists.techgetafrica.com/">therapists.techgetafrica.com</a>. '
        || 'Questions? Just reply to this email.'
    ),
    'Hi ' || split_part(app.full_name, ' ', 1) || ',' || E'\n\n'
      || 'Thank you for applying to join the care team on Δεν είσαι μόνος. '
      || 'We can’t approve your application as it stands.'
      || coalesce(E'\n\n' || v_reason, '') || E'\n\n'
      || 'You can update it and send it again at https://therapists.techgetafrica.com/',
    'therapist-application-declined/' || p_id || '/' || extract(epoch from now())::bigint
  );
  return null;
end;
$$;

revoke execute on function public.kyc_check_keys() from public, anon, authenticated;
revoke execute on function public.kyc_file_ok(text) from public, anon, authenticated;
revoke execute on function public.therapist_submit_application(text, text, text, text, text, text, text, text[], text[], integer, text, date, text, text, text, date, text, text, text, text) from public, anon;
revoke execute on function public.admin_list_therapist_applications() from public, anon;
revoke execute on function public.admin_review_therapist_application(uuid, boolean, text, text[]) from public, anon;
grant execute on function public.therapist_submit_application(text, text, text, text, text, text, text, text[], text[], integer, text, date, text, text, text, date, text, text, text, text) to authenticated;
grant execute on function public.admin_list_therapist_applications() to authenticated;
grant execute on function public.admin_review_therapist_application(uuid, boolean, text, text[]) to authenticated;
