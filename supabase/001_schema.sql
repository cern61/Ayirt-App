-- =====================================================================
--  AYIRT — Supabase veritabanı şeması
-- =====================================================================

-- ---------------------------------------------------------------------
-- 0) Tipler
-- ---------------------------------------------------------------------
create type public.user_role as enum ('customer', 'business', 'admin');
create type public.booking_status as enum ('pending', 'confirmed', 'cancelled', 'completed');

-- ---------------------------------------------------------------------
-- 1) Tablolar
-- ---------------------------------------------------------------------

-- Her auth kullanıcısının bir profili var (kayıtta trigger ile oluşur)
create table public.profiles (
  id          uuid primary key references auth.users (id) on delete cascade,
  role        public.user_role not null default 'customer',
  full_name   text not null default '',
  email       text not null,
  phone       text,
  avatar_url  text,
  created_at  timestamptz not null default now()
);

create table public.categories (
  id          serial primary key,
  name        text not null unique,
  icon        text not null default 'store',   -- Flutter'da Material ikon adı
  sort_order  int  not null default 0
);

-- Her işletme sahibinin TEK işletmesi var (owner_id unique)
create table public.businesses (
  id                 uuid primary key default gen_random_uuid(),
  owner_id           uuid not null unique references public.profiles (id) on delete cascade,
  name               text not null,
  category_id        int references public.categories (id) on delete set null,
  description        text not null default '',
  phone              text,
  email              text,
  address            text,
  city               text,
  logo_url           text,
  -- "İhtiyaca göre ayarlanabilir takvim":
  slot_minutes       int not null default 30 check (slot_minutes between 5 and 480),
  capacity_per_slot  int not null default 1  check (capacity_per_slot between 1 and 500),
  is_active          boolean not null default true,   -- admin askıya alabilir
  created_at         timestamptz not null default now()
);

create table public.services (
  id            uuid primary key default gen_random_uuid(),
  business_id   uuid not null references public.businesses (id) on delete cascade,
  name          text not null,
  duration_min  int  not null default 30 check (duration_min > 0),
  price         numeric(10,2) check (price >= 0),
  is_active     boolean not null default true,
  created_at    timestamptz not null default now()
);

-- Haftalık çalışma saatleri. weekday: 1 = Pazartesi ... 7 = Pazar
-- (Dart'taki DateTime.weekday ile birebir aynı)
create table public.working_hours (
  business_id  uuid not null references public.businesses (id) on delete cascade,
  weekday      smallint not null check (weekday between 1 and 7),
  is_open      boolean not null default true,
  open_time    time not null default '09:00',
  close_time   time not null default '18:00',
  primary key (business_id, weekday),
  check (close_time > open_time)
);

-- Tatil / özel kapalı günler
create table public.closed_dates (
  business_id  uuid not null references public.businesses (id) on delete cascade,
  day          date not null,
  reason       text,
  primary key (business_id, day)
);

create table public.bookings (
  id           uuid primary key default gen_random_uuid(),
  business_id  uuid not null references public.businesses (id) on delete cascade,
  customer_id  uuid not null references public.profiles (id) on delete cascade,
  service_id   uuid references public.services (id) on delete set null,
  start_at     timestamptz not null,
  end_at       timestamptz not null,
  party_size   int not null default 1 check (party_size >= 1),
  status       public.booking_status not null default 'pending',
  note         text,
  created_at   timestamptz not null default now(),
  check (end_at > start_at)
);
create index bookings_business_start_idx on public.bookings (business_id, start_at);
create index bookings_customer_start_idx on public.bookings (customer_id, start_at desc);

create table public.reviews (
  id             uuid primary key default gen_random_uuid(),
  booking_id     uuid not null unique references public.bookings (id) on delete cascade,
  business_id    uuid not null references public.businesses (id) on delete cascade,
  customer_id    uuid not null references public.profiles (id) on delete cascade,
  customer_name  text not null default '',  -- yorumda görünen isim (trigger doldurur)
  rating         smallint not null check (rating between 1 and 5),
  comment        text,
  created_at     timestamptz not null default now()
);
create index reviews_business_idx on public.reviews (business_id, created_at desc);

-- ---------------------------------------------------------------------
-- 2) Yardımcı fonksiyonlar (RLS içinde kullanılır)
-- ---------------------------------------------------------------------
create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.profiles where id = auth.uid() and role = 'admin');
$$;

create or replace function public.my_business_id()
returns uuid language sql stable security definer set search_path = public as $$
  select id from public.businesses where owner_id = auth.uid();
$$;

-- ---------------------------------------------------------------------
-- 3) Trigger'lar
-- ---------------------------------------------------------------------

-- 3.1 Kayıt olunca profil (+ işletmeyse işletme ve çalışma saatleri) oluştur.
--     Rol, kayıt formundan "customer" veya "business" gelir.
--     Admin ASLA kayıtla oluşmaz
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_role public.user_role;
  v_business_id uuid;
begin
  v_role := case when new.raw_user_meta_data ->> 'role' = 'business'
                 then 'business'::public.user_role
                 else 'customer'::public.user_role end;

  insert into public.profiles (id, role, full_name, email, phone)
  values (new.id, v_role,
          coalesce(new.raw_user_meta_data ->> 'full_name', ''),
          new.email,
          new.raw_user_meta_data ->> 'phone');

  if v_role = 'business' then
    insert into public.businesses (owner_id, name, category_id, email, phone)
    values (new.id,
            coalesce(nullif(new.raw_user_meta_data ->> 'business_name', ''), 'Yeni İşletme'),
            nullif(new.raw_user_meta_data ->> 'category_id', '')::int,
            new.email,
            new.raw_user_meta_data ->> 'phone')
    returning id into v_business_id;

    insert into public.working_hours (business_id, weekday, is_open)
    select v_business_id, d, d <= 6 from generate_series(1, 7) as d;
  end if;

  return new;
end $$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- 3.2 Kullanıcı kendi rolünü değiştiremesin (sadece admin / SQL Editor)
create or replace function public.protect_profile_fields()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is not null and not public.is_admin() then
    new.role  := old.role;
    new.email := old.email;
  end if;
  return new;
end $$;

create trigger profiles_protect
  before update on public.profiles
  for each row execute function public.protect_profile_fields();

-- 3.3 İşletme sahibi kendi işletmesini aktifleştiremesin / sahibini değiştiremesin
create or replace function public.protect_business_fields()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is not null and not public.is_admin() then
    new.is_active := old.is_active;
    new.owner_id  := old.owner_id;
  end if;
  return new;
end $$;

create trigger businesses_protect
  before update on public.businesses
  for each row execute function public.protect_business_fields();

-- 3.4 Yoruma müşterinin adını yaz (diğer profil bilgileri gizli kalsın)
create or replace function public.fill_review_name()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  select coalesce(nullif(full_name, ''), 'Müşteri') into new.customer_name
  from public.profiles where id = new.customer_id;
  return new;
end $$;

create trigger reviews_fill_name
  before insert on public.reviews
  for each row execute function public.fill_review_name();

-- ---------------------------------------------------------------------
-- 4) Row Level Security (RLS)
-- ---------------------------------------------------------------------
alter table public.profiles      enable row level security;
alter table public.categories    enable row level security;
alter table public.businesses    enable row level security;
alter table public.services      enable row level security;
alter table public.working_hours enable row level security;
alter table public.closed_dates  enable row level security;
alter table public.bookings      enable row level security;
alter table public.reviews       enable row level security;

-- PROFILES: kendini gör; işletme kendi müşterilerini görür; admin herkesi
create policy profiles_select on public.profiles for select to authenticated
  using (
    id = auth.uid()
    or public.is_admin()
    or exists (select 1 from public.bookings b
               where b.customer_id = profiles.id
                 and b.business_id = public.my_business_id())
  );
create policy profiles_update on public.profiles for update to authenticated
  using (id = auth.uid() or public.is_admin())
  with check (id = auth.uid() or public.is_admin());
create policy profiles_delete on public.profiles for delete to authenticated
  using (public.is_admin());

-- CATEGORIES: herkes okur (kayıt ekranında da lazım → anon dahil), admin yönetir
create policy categories_select on public.categories for select to anon, authenticated using (true);
create policy categories_admin on public.categories for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

-- BUSINESSES: aktif olanları herkes görür; sahibi ve admin düzenler
create policy businesses_select on public.businesses for select to authenticated
  using (is_active or owner_id = auth.uid() or public.is_admin());
create policy businesses_update on public.businesses for update to authenticated
  using (owner_id = auth.uid() or public.is_admin())
  with check (owner_id = auth.uid() or public.is_admin());
create policy businesses_delete on public.businesses for delete to authenticated
  using (public.is_admin());
-- (INSERT politikası yok: işletme sadece kayıt trigger'ı ile oluşur)

-- SERVICES / WORKING_HOURS / CLOSED_DATES: herkes okur, sahibi + admin yazar
create policy services_select on public.services for select to authenticated using (true);
create policy services_write on public.services for all to authenticated
  using (business_id = public.my_business_id() or public.is_admin())
  with check (business_id = public.my_business_id() or public.is_admin());

create policy hours_select on public.working_hours for select to authenticated using (true);
create policy hours_write on public.working_hours for all to authenticated
  using (business_id = public.my_business_id() or public.is_admin())
  with check (business_id = public.my_business_id() or public.is_admin());

create policy closed_select on public.closed_dates for select to authenticated using (true);
create policy closed_write on public.closed_dates for all to authenticated
  using (business_id = public.my_business_id() or public.is_admin())
  with check (business_id = public.my_business_id() or public.is_admin());

-- BOOKINGS: müşteri kendininkini, işletme kendininkini, admin hepsini görür.
-- Ekleme ve durum değişikliği SADECE aşağıdaki RPC fonksiyonlarıyla yapılır.
create policy bookings_select on public.bookings for select to authenticated
  using (customer_id = auth.uid()
         or business_id = public.my_business_id()
         or public.is_admin());
create policy bookings_admin on public.bookings for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

-- REVIEWS: herkes okur; müşteri sadece TAMAMLANMIŞ kendi randevusuna yorum yazar
create policy reviews_select on public.reviews for select to authenticated using (true);
create policy reviews_insert on public.reviews for insert to authenticated
  with check (
    customer_id = auth.uid()
    and exists (select 1 from public.bookings b
                where b.id = booking_id
                  and b.customer_id = auth.uid()
                  and b.business_id = reviews.business_id
                  and b.status = 'completed')
  );
create policy reviews_modify on public.reviews for update to authenticated
  using (customer_id = auth.uid() or public.is_admin())
  with check (customer_id = auth.uid() or public.is_admin());
create policy reviews_delete on public.reviews for delete to authenticated
  using (customer_id = auth.uid() or public.is_admin());

-- ---------------------------------------------------------------------
-- 5) Arama/listeleme için görünüm (puan ortalaması + popülerlik)
-- ---------------------------------------------------------------------
create or replace view public.business_cards
with (security_invoker = true) as
select
  b.id, b.name, b.description, b.city, b.address, b.phone, b.email,
  b.logo_url, b.category_id, c.name as category_name,
  b.slot_minutes, b.capacity_per_slot, b.is_active,
  coalesce(round(avg(r.rating)::numeric, 1), 0)::numeric(2,1) as rating_avg,
  count(r.id)::int as rating_count
from public.businesses b
left join public.categories c on c.id = b.category_id
left join public.reviews r on r.business_id = b.id
group by b.id, c.name;

-- ---------------------------------------------------------------------
-- 6) RPC fonksiyonları (Flutter'dan supabase.rpc(...) ile çağrılır)
-- ---------------------------------------------------------------------

-- 6.1 Bir günün müsait saatleri (İstanbul saatine göre)
create or replace function public.get_available_slots(p_business uuid, p_day date)
returns table (slot_start timestamptz, slot_end timestamptz, remaining int)
language plpgsql stable security definer set search_path = public as $$
declare
  v_slot int;
  v_cap  int;
  v_open time;
  v_close time;
  v_is_open boolean;
begin
  select slot_minutes, capacity_per_slot into v_slot, v_cap
  from public.businesses where id = p_business and is_active;
  if not found then return; end if;

  if exists (select 1 from public.closed_dates where business_id = p_business and day = p_day) then
    return;
  end if;

  select is_open, open_time, close_time into v_is_open, v_open, v_close
  from public.working_hours
  where business_id = p_business and weekday = extract(isodow from p_day)::int;
  if not found or not v_is_open then return; end if;

  return query
  with slots as (
    select (t at time zone 'Europe/Istanbul') as s
    from generate_series(p_day + v_open,
                         p_day + v_close - make_interval(mins => v_slot),
                         make_interval(mins => v_slot)) as t
  )
  select s.s,
         s.s + make_interval(mins => v_slot),
         (v_cap - coalesce((
            select sum(b.party_size) from public.bookings b
            where b.business_id = p_business
              and b.status in ('pending', 'confirmed')
              and b.start_at < s.s + make_interval(mins => v_slot)
              and b.end_at   > s.s
          ), 0))::int
  from slots s
  where s.s > now()
  order by s.s;
end $$;

-- 6.2 Rezervasyon oluştur (çakışma ve kapasite kontrolü veritabanında)
create or replace function public.create_booking(
  p_business   uuid,
  p_start      timestamptz,
  p_service    uuid default null,
  p_party_size int  default 1,
  p_note       text default null
) returns public.bookings
language plpgsql security definer set search_path = public as $$
declare
  v_uid  uuid := auth.uid();
  v_slot int;
  v_remaining int;
  v_day  date;
  v_row  public.bookings;
begin
  if v_uid is null then
    raise exception 'Giriş yapmalısın';
  end if;
  if not exists (select 1 from public.profiles where id = v_uid and role = 'customer') then
    raise exception 'Sadece müşteri hesapları rezervasyon yapabilir';
  end if;
  if p_party_size < 1 then
    raise exception 'Kişi sayısı en az 1 olmalı';
  end if;
  if p_service is not null and not exists (
       select 1 from public.services
       where id = p_service and business_id = p_business and is_active) then
    raise exception 'Hizmet bu işletmeye ait değil';
  end if;

  -- Aynı işletmeye aynı anda gelen iki isteği sıraya sok (çifte rezervasyon engeli)
  perform pg_advisory_xact_lock(hashtext(p_business::text));

  v_day := (p_start at time zone 'Europe/Istanbul')::date;

  select s.remaining into v_remaining
  from public.get_available_slots(p_business, v_day) s
  where s.slot_start = p_start;

  if v_remaining is null then
    raise exception 'Bu saat müsait değil';
  end if;
  if v_remaining < p_party_size then
    raise exception 'Bu saatte yeterli yer yok (kalan: %)', v_remaining;
  end if;

  select slot_minutes into v_slot from public.businesses where id = p_business;

  insert into public.bookings (business_id, customer_id, service_id, start_at, end_at, party_size, note)
  values (p_business, v_uid, p_service, p_start,
          p_start + make_interval(mins => v_slot), p_party_size, p_note)
  returning * into v_row;

  return v_row;
end $$;

-- 6.3 Rezervasyon durumunu değiştir (kim neyi yapabilir kuralları burada)
create or replace function public.update_booking_status(
  p_booking uuid,
  p_status  public.booking_status
) returns public.bookings
language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  v_b   public.bookings;
  v_is_owner boolean;
begin
  select * into v_b from public.bookings where id = p_booking for update;
  if not found then
    raise exception 'Rezervasyon bulunamadı';
  end if;

  v_is_owner := v_b.business_id = public.my_business_id();

  if public.is_admin() then
    null; -- admin her şeyi yapabilir

  elsif v_b.customer_id = v_uid then
    -- Müşteri: sadece ileri tarihli, aktif randevusunu iptal edebilir
    if p_status <> 'cancelled' or v_b.status not in ('pending', 'confirmed') then
      raise exception 'Bu işlemi yapamazsın';
    end if;
    if v_b.start_at <= now() then
      raise exception 'Geçmiş randevu iptal edilemez';
    end if;

  elsif v_is_owner then
    -- İşletme: onayla / iptal et / tamamlandı olarak işaretle
    if not (
         (p_status = 'confirmed' and v_b.status = 'pending')
      or (p_status = 'cancelled' and v_b.status in ('pending', 'confirmed'))
      or (p_status = 'completed' and v_b.status = 'confirmed')
    ) then
      raise exception 'Geçersiz durum geçişi: % → %', v_b.status, p_status;
    end if;

  else
    raise exception 'Bu rezervasyon üzerinde yetkin yok';
  end if;

  update public.bookings set status = p_status where id = p_booking returning * into v_b;
  return v_b;
end $$;

-- 6.4 Admin dashboard istatistikleri
create or replace function public.admin_stats()
returns json language plpgsql stable security definer set search_path = public as $$
begin
  if not public.is_admin() then
    raise exception 'Yetkisiz';
  end if;
  return json_build_object(
    'customers',       (select count(*) from public.profiles where role = 'customer'),
    'businesses',      (select count(*) from public.businesses),
    'active_businesses',(select count(*) from public.businesses where is_active),
    'bookings_total',  (select count(*) from public.bookings),
    'bookings_today',  (select count(*) from public.bookings
                        where (start_at at time zone 'Europe/Istanbul')::date
                              = (now() at time zone 'Europe/Istanbul')::date),
    'bookings_pending',(select count(*) from public.bookings where status = 'pending')
  );
end $$;

-- ---------------------------------------------------------------------
-- 7) Yetkiler (Data API'nin tablolara erişebilmesi için)
-- ---------------------------------------------------------------------
grant usage on schema public to authenticated;
grant select, insert, update, delete on all tables in schema public to authenticated;
grant usage, select on all sequences in schema public to authenticated;
grant execute on function public.get_available_slots(uuid, date)            to authenticated;
grant execute on function public.create_booking(uuid, timestamptz, uuid, int, text) to authenticated;
grant execute on function public.update_booking_status(uuid, public.booking_status) to authenticated;
grant execute on function public.admin_stats()                               to authenticated;

-- Giriş yapmamış (anon) kullanıcılar sadece kategori listesini görebilsin
revoke all on all tables in schema public from anon;
grant usage on schema public to anon;
grant select on public.categories to anon;
revoke execute on function public.create_booking(uuid, timestamptz, uuid, int, text) from anon, public;
revoke execute on function public.update_booking_status(uuid, public.booking_status) from anon, public;
revoke execute on function public.admin_stats() from anon, public;
revoke execute on function public.get_available_slots(uuid, date) from anon, public;

-- ---------------------------------------------------------------------
-- 8) Başlangıç verisi: kategoriler
-- ---------------------------------------------------------------------
insert into public.categories (name, icon, sort_order) values
  ('Kuaför & Berber',  'content_cut',      1),
  ('Güzellik & Spa',   'spa',              2),
  ('Sağlık & Klinik',  'medical_services', 3),
  ('Spor & Fitness',   'fitness_center',   4),
  ('Restoran & Kafe',  'restaurant',       5),
  ('Halı Saha',        'sports_soccer',    6),
  ('Eğitim & Kurs',    'school',           7),
  ('Diğer',            'store',            8);

-- ---------------------------------------------------------------------
-- 9) Fotoğraflar için Storage (profil fotoğrafı ve işletme logosu)
--    Dosya yolu: <kullanici_id>/dosya.jpg  → herkes sadece kendi klasörüne yazar
-- ---------------------------------------------------------------------
insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true)
on conflict (id) do nothing;

create policy avatars_insert_own on storage.objects for insert to authenticated
  with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);
create policy avatars_update_own on storage.objects for update to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);
create policy avatars_delete_own on storage.objects for delete to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);
