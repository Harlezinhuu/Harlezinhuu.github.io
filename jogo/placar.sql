-- Placar online do Harle: Anti-Lag
-- Cole tudo isso no Supabase em: SQL Editor > New query > Run.
-- Pode rodar de novo sem problema (não apaga as pontuações).

create table if not exists public.antilag_placar (
  id          bigint generated always as identity primary key,
  nome        text        not null,
  pontos      integer     not null,
  onda        integer     not null,
  abates      integer     not null,
  duracao_s   integer     not null,
  ip_hash     text,
  criado_em   timestamptz not null default now()
);
create index if not exists antilag_placar_pontos on public.antilag_placar (pontos desc);
create index if not exists antilag_placar_ip on public.antilag_placar (ip_hash, criado_em desc);

-- Ninguém mexe na tabela direto: só pelas duas funções abaixo.
alter table public.antilag_placar enable row level security;
revoke all on public.antilag_placar from anon, authenticated;

-- Enviar uma pontuação (com checagens para barrar números impossíveis e spam)
create or replace function public.antilag_enviar(p_nome text, p_pontos integer, p_onda integer, p_abates integer, p_duracao integer)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_nome text := regexp_replace(trim(coalesce(p_nome, '')), '\s+', ' ', 'g');
  v_ip   text;
  v_hash text;
  v_pos  integer;
  v_total integer;
begin
  if char_length(v_nome) < 2 or char_length(v_nome) > 16
     or v_nome !~ '^[A-Za-zÀ-ÖØ-öø-ÿ0-9 _.\-]+$' then
    raise exception 'nome_invalido';
  end if;
  if p_onda is null or p_onda < 1 or p_onda > 1000
     or p_pontos is null or p_pontos < 1
     or p_abates is null or p_abates < 0
     or p_duracao is null or p_duracao < 1 then
    raise exception 'dados_invalidos';
  end if;
  -- limites generosos baseados em quanto o jogo consegue dar de verdade
  if p_pontos > p_onda * (p_onda + 10) * 400 + p_onda * 2000
     or p_abates > p_onda * (p_onda + 10) * 6
     or p_duracao < (p_onda - 1) * 6 then
    raise exception 'pontuacao_impossivel';
  end if;

  -- no máximo 1 envio a cada 20 segundos por conexão (o IP é guardado só como hash)
  begin
    v_ip := split_part(coalesce(current_setting('request.headers', true)::json ->> 'x-forwarded-for', ''), ',', 1);
  exception when others then
    v_ip := '';
  end;
  if v_ip <> '' then
    v_hash := md5('antilag:' || v_ip);
    if exists (select 1 from antilag_placar where ip_hash = v_hash and criado_em > now() - interval '20 seconds') then
      raise exception 'muito_rapido';
    end if;
  end if;

  insert into antilag_placar (nome, pontos, onda, abates, duracao_s, ip_hash)
  values (v_nome, p_pontos, p_onda, p_abates, p_duracao, v_hash);

  -- posição = quantos jogadores (melhor resultado de cada nome) ficaram acima + 1
  select count(*) + 1 into v_pos from (
    select lower(nome) n, max(pontos) m from antilag_placar group by lower(nome)
  ) t where t.m > p_pontos and t.n <> lower(v_nome);
  select count(distinct lower(nome)) into v_total from antilag_placar;

  return json_build_object('posicao', v_pos, 'total', v_total);
end;
$$;

-- Os melhores (um resultado por nome: o melhor de cada um)
create or replace function public.antilag_top(p_limite integer default 10)
returns table (posicao bigint, nome text, pontos integer, onda integer, criado_em timestamptz)
language sql
stable
security definer
set search_path = public
as $$
  select row_number() over (order by b.pontos desc, b.criado_em asc), b.nome, b.pontos, b.onda, b.criado_em
  from (
    select distinct on (lower(nome)) nome, pontos, onda, criado_em
    from antilag_placar
    order by lower(nome), pontos desc, criado_em asc
  ) b
  order by b.pontos desc, b.criado_em asc
  limit least(greatest(coalesce(p_limite, 10), 1), 50);
$$;

revoke all on function public.antilag_enviar(text, integer, integer, integer, integer) from public;
revoke all on function public.antilag_top(integer) from public;
grant execute on function public.antilag_enviar(text, integer, integer, integer, integer) to anon, authenticated;
grant execute on function public.antilag_top(integer) to anon, authenticated;

-- Para apagar um nome ofensivo: Table Editor > antilag_placar > selecionar a linha > Delete.
