-- 0028: Therapists apply on the therapist site; admins approve them.
--
-- Anyone with a confirmed account can send one application. It stays in
-- public.therapist_applications, which only the functions below read, until
-- an admin approves or declines it on the admin page. Approving creates the
-- therapist profile and the therapist_accounts row, so nobody sees a client
-- before an admin has checked their licence. Approved therapists keep their
-- own profile up to date from the site; their name and credentials stay
-- with the admins, because clients rely on them.
--
-- Paste-run this in the Supabase dashboard → SQL Editor. Safe to re-run.

create table if not exists public.therapist_applications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references auth.users (id) on delete cascade,
  email text not null check (email = lower(trim(email))),
  full_name text not null check (length(trim(full_name)) between 2 and 120),
  title text check (length(title) <= 120),
  credentials text not null check (length(trim(credentials)) between 2 and 200),
  licence_number text not null check (length(trim(licence_number)) between 2 and 80),
  licence_body text not null check (length(trim(licence_body)) between 2 and 160),
  country text not null check (length(trim(country)) between 2 and 80),
  bio text check (length(bio) <= 2000),
  specialties text[] not null default '{}',
  languages text[] not null default '{}',
  years_experience smallint check (years_experience between 0 and 70),
  photo_url text check (length(photo_url) <= 500),
  status text not null default 'pending' check (status in ('pending', 'approved', 'declined')),
  decline_reason text check (length(decline_reason) <= 1000),
  therapist_id uuid references public.therapists (id) on delete set null,
  reviewed_by text,
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.therapist_applications enable row level security;
-- No policies: only the security-definer functions below read it.

-- Applicants and therapists upload their own photo under self/<user id>/.
drop policy if exists "People upload their own therapist photo" on storage.objects;
create policy "People upload their own therapist photo"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'therapist-photos'
    and (storage.foldername(name))[1] = 'self'
    and (storage.foldername(name))[2] = (select auth.uid())::text
  );

drop policy if exists "People replace their own therapist photo" on storage.objects;
create policy "People replace their own therapist photo"
  on storage.objects for update to authenticated
  using (
    bucket_id = 'therapist-photos'
    and (storage.foldername(name))[1] = 'self'
    and (storage.foldername(name))[2] = (select auth.uid())::text
  );

-- Keeps the text arrays short and tidy: trimmed, no blanks, no repeats.
create or replace function public.clean_tags(p_tags text[], p_max integer)
returns text[]
language sql
immutable
set search_path = ''
as $$
  select coalesce(array_agg(t order by first), '{}')
  from (
    select left(trim(x), 60) as t, min(ord) as first
    from unnest(coalesce(p_tags, '{}')) with ordinality as u(x, ord)
    where trim(x) <> ''
    group by left(trim(x), 60)
    order by min(ord)
    limit p_max
  ) s;
$$;

-- Only our own photo bucket, so a profile can't point at any address.
create or replace function public.therapist_photo_ok(p_url text)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select p_url is null
    or (length(p_url) <= 500
        and p_url ~ '^https://[a-z0-9]+\.supabase\.co/storage/v1/object/public/therapist-photos/[A-Za-z0-9/_.?=-]+$');
$$;

-- What the therapist site needs to know about whoever is signed in.
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
        'active', t.active
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
        'created_at', a.created_at, 'updated_at', a.updated_at
      )
      from public.therapist_applications a where a.user_id = auth.uid()
    )
  ) into result;
  return result;
end;
$$;

-- Sends, or after a decline re-sends, the signed-in person's application.
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
  p_photo_url text
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

  insert into public.therapist_applications as a (
    user_id, email, full_name, title, credentials, licence_number,
    licence_body, country, bio, specialties, languages, years_experience,
    photo_url
  )
  values (
    auth.uid(), v_email, v_name, nullif(trim(p_title), ''), trim(p_credentials),
    trim(p_licence_number), trim(p_licence_body), trim(p_country),
    nullif(trim(p_bio), ''), public.clean_tags(p_specialties, 12),
    public.clean_tags(p_languages, 10), p_years_experience, v_photo
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
        || public.email_row('Email', public.email_escape(v_email))
        || '</table>'),
      'Check the licence with the issuing body, then approve or decline it under Applications on the admin page.'
    ),
    v_name || ' has applied to join the care team.' || E'\n\n'
      || 'Licence: ' || trim(p_licence_number) || ', issued by ' || trim(p_licence_body)
      || ' (' || trim(p_country) || ')' || E'\n' || 'Email: ' || v_email || E'\n\n'
      || 'Check the licence, then approve or decline it under Applications on the admin page.',
    'therapist-application/' || v_id || '/' || extract(epoch from now())::bigint
  );
  return v_id;
end;
$$;

-- An approved therapist edits what clients see about them. Name and
-- credentials are checked by an admin, so they change only on the admin page.
create or replace function public.therapist_update_profile(
  p_title text,
  p_bio text,
  p_specialties text[],
  p_languages text[],
  p_years_experience integer,
  p_photo_url text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := public.current_therapist_id();
  v_photo text := nullif(trim(coalesce(p_photo_url, '')), '');
begin
  if me is null then
    raise exception 'Therapists only' using errcode = '42501';
  end if;
  if p_years_experience is not null and p_years_experience not between 0 and 70 then
    raise exception 'Years of experience should be between 0 and 70.' using errcode = '22023';
  end if;
  if not public.therapist_photo_ok(v_photo) then
    raise exception 'Upload your photo from this page.' using errcode = '22023';
  end if;
  if length(coalesce(p_title, '')) > 120 or length(coalesce(p_bio, '')) > 2000 then
    raise exception 'That’s a little long. Shorten your title or bio.' using errcode = '22023';
  end if;
  update public.therapists
  set title = nullif(trim(p_title), ''),
      bio = nullif(trim(p_bio), ''),
      specialties = public.clean_tags(p_specialties, 12),
      languages = public.clean_tags(p_languages, 10),
      years_experience = p_years_experience,
      photo_url = v_photo,
      updated_at = now()
  where id = me;
end;
$$;

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
  updated_at timestamptz
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
           a.therapist_id, a.reviewed_by, a.reviewed_at, a.created_at, a.updated_at
    from public.therapist_applications a
    order by (a.status = 'pending') desc, a.updated_at desc
    limit 500;
end;
$$;

-- Approve: the application becomes a therapist profile and sign-in (the
-- welcome email goes from the therapist_accounts trigger). Decline: the
-- applicant is told, with the reason if there is one, and can apply again.
create or replace function public.admin_review_therapist_application(
  p_id uuid,
  p_approve boolean,
  p_reason text default null
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

  if coalesce(p_approve, false) then
    if exists (select 1 from public.therapist_accounts ta where ta.email = app.email) then
      raise exception 'A therapist already signs in with %. Link them on the Therapists page instead.', app.email
        using errcode = '23505';
    end if;
    insert into public.therapists (
      full_name, title, credentials, bio, specialties, languages,
      years_experience, photo_url, active
    )
    values (
      app.full_name, app.title,
      left(app.credentials || ' · Licence ' || app.licence_number || ' (' || app.licence_body || ')', 200),
      app.bio, app.specialties, app.languages, app.years_experience,
      app.photo_url, true
    )
    returning id into therapist;
    insert into public.therapist_accounts (therapist_id, email)
    values (therapist, app.email);
    update public.therapist_applications
    set status = 'approved', therapist_id = therapist,
        reviewed_by = public.current_user_email(), reviewed_at = now(),
        updated_at = now()
    where id = p_id;
    return therapist;
  end if;

  update public.therapist_applications
  set status = 'declined', decline_reason = v_reason,
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

-- The welcome email now points at the therapist site as well as the app.
create or replace function public.notify_therapist_invited()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  care_team constant text := 'reagan.e.owiti@gmail.com';
  site constant text := 'https://therapists.techgetafrica.com/';
  therapist_name text;
begin
  if tg_op = 'UPDATE' and new.email = old.email then
    return new;
  end if;
  select t.full_name into therapist_name
    from public.therapists t where t.id = new.therapist_id;
  perform public.send_app_email(
    new.email,
    care_team,
    'You’ve been added as a therapist',
    public.email_layout(
      'Sign in with this email to see your sessions.',
      'Welcome to the care team',
      'Hi ' || public.email_escape(split_part(coalesce(therapist_name, ''), ' ', 1))
        || ', you’ve been added as a therapist on Δεν είσαι μόνος.',
      public.email_box('#F6F6F6', 'Getting started',
        '<div style="font-size:12.5px;line-height:1.55;color:#6E6E73;">'
        || 'Sign in at <a href="' || site || '">therapists.techgetafrica.com</a> with '
        || '<strong style="font-weight:600;color:#191919;">'
        || public.email_escape(new.email) || '</strong> — with Google, or with a '
        || 'password and the confirmation email. You’ll see your sessions, take '
        || 'each video call in the browser, and keep your profile up to date. '
        || 'Your sessions are also in the app, under '
        || '<strong style="font-weight:600;color:#191919;">Settings → My therapy sessions</strong>.</div>'),
      'Questions? Just reply to this email.'
    ),
    'Hi ' || split_part(coalesce(therapist_name, ''), ' ', 1) || ','
      || E'\n\n'
      || 'You’ve been added as a therapist on Δεν είσαι μόνος. Sign in at '
      || site || ' with ' || new.email || ' (Google, or a password and the '
      || 'confirmation email) to see your sessions, take each video call in the '
      || 'browser and keep your profile up to date. Your sessions are also in '
      || 'the app, under Settings → My therapy sessions.',
    'therapist-invite/' || new.therapist_id || '/' || md5(new.email)
  );
  return new;
end;
$$;

revoke execute on function public.clean_tags(text[], integer) from public, anon, authenticated;
revoke execute on function public.therapist_photo_ok(text) from public, anon, authenticated;
revoke execute on function public.therapist_portal_status() from public, anon;
revoke execute on function public.therapist_submit_application(text, text, text, text, text, text, text, text[], text[], integer, text) from public, anon;
revoke execute on function public.therapist_update_profile(text, text, text[], text[], integer, text) from public, anon;
revoke execute on function public.admin_list_therapist_applications() from public, anon;
revoke execute on function public.admin_review_therapist_application(uuid, boolean, text) from public, anon;
grant execute on function public.therapist_portal_status() to authenticated;
grant execute on function public.therapist_submit_application(text, text, text, text, text, text, text, text[], text[], integer, text) to authenticated;
grant execute on function public.therapist_update_profile(text, text, text[], text[], integer, text) to authenticated;
grant execute on function public.admin_list_therapist_applications() to authenticated;
grant execute on function public.admin_review_therapist_application(uuid, boolean, text) to authenticated;
