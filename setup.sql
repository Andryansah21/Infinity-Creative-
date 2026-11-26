-- =====================================================================
--  SETUP DATABASE — jalankan SEKALI di Supabase > SQL Editor > New query
--  Isi: pengaturan situs, pesan masuk, statistik kunjungan, penyimpanan gambar
-- =====================================================================

-- 1) Tabel ------------------------------------------------------------
create table if not exists public.site_settings (
  id int primary key default 1 check (id = 1),
  data jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

create table if not exists public.messages (
  id bigint generated always as identity primary key,
  created_at timestamptz not null default now(),
  name text not null check (char_length(name) between 1 and 120),
  email text check (char_length(email) <= 200),
  phone text check (char_length(phone) <= 40),
  service text check (char_length(service) <= 120),
  message text not null check (char_length(message) between 1 and 3000),
  channel text not null default 'form' check (channel in ('form','whatsapp')),
  status text not null default 'baru' check (status in ('baru','dibaca','selesai'))
);

create table if not exists public.events (
  id bigint generated always as identity primary key,
  created_at timestamptz not null default now(),
  type text not null check (type in ('visit','project_open','wa_click','order','cv_download','form_sent')),
  label text check (char_length(label) <= 120),
  path text check (char_length(path) <= 200),
  ref text check (char_length(ref) <= 200),
  device text check (device in ('mobile','desktop')),
  sid text check (char_length(sid) <= 40)
);
create index if not exists events_created_idx on public.events (created_at);
create index if not exists messages_created_idx on public.messages (created_at);

-- 2) Keamanan (Row Level Security) -------------------------------------
alter table public.site_settings enable row level security;
alter table public.messages      enable row level security;
alter table public.events        enable row level security;

-- Pengunjung: boleh MEMBACA pengaturan, boleh MENGIRIM pesan & event. Tidak boleh membaca pesan/statistik.
create policy "settings: publik baca"   on public.site_settings for select to anon, authenticated using (true);
create policy "settings: admin tulis"   on public.site_settings for insert to authenticated with check (true);
create policy "settings: admin ubah"    on public.site_settings for update to authenticated using (true) with check (true);

create policy "messages: publik kirim"  on public.messages for insert to anon, authenticated with check (true);
create policy "messages: admin baca"    on public.messages for select to authenticated using (true);
create policy "messages: admin ubah"    on public.messages for update to authenticated using (true) with check (true);
create policy "messages: admin hapus"   on public.messages for delete to authenticated using (true);

create policy "events: publik kirim"    on public.events for insert to anon, authenticated with check (true);
create policy "events: admin baca"      on public.events for select to authenticated using (true);
create policy "events: admin hapus"     on public.events for delete to authenticated using (true);

grant select on public.site_settings to anon, authenticated;
grant insert, update on public.site_settings to authenticated;
grant insert on public.messages, public.events to anon, authenticated;
grant select, update, delete on public.messages to authenticated;
grant select, delete on public.events to authenticated;

-- 3) Penyimpanan gambar (bucket "media", publik untuk dibaca) -----------
insert into storage.buckets (id, name, public) values ('media', 'media', true)
on conflict (id) do nothing;

create policy "media: admin unggah" on storage.objects for insert to authenticated with check (bucket_id = 'media');
create policy "media: admin ubah"   on storage.objects for update to authenticated using (bucket_id = 'media');
create policy "media: admin hapus"  on storage.objects for delete to authenticated using (bucket_id = 'media');
