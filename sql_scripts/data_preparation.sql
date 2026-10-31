-- Active: 1745477253100@@127.0.0.1@3306@logistic_db
-- =====================================================================
-- Distribution Hub Optimizer (India)
-- Database : logistic_db
-- =====================================================================

show tables;

select * from bill limit 5;
select * from gsdp limit 5;
select * from population limit 5;


-- =====================================================================
-- 1. STATE NAME STANDARDISATION
-- =====================================================================
drop table if exists state_alias;

create table state_alias (
    alias varchar(80) primary key,
    state varchar(80) not null
);

insert into state_alias (alias, state) values
    ('andaman and nicobar islands', 'andaman and nicobar'),
    ('andaman and nicobar', 'andaman and nicobar'),
    ('jammu and kashmir', 'jammu and kashmir'),
    ('ladakh', 'jammu and kashmir'),
    ('daman and diu', 'dadra and nagar haveli and daman and diu'),
    ('dadra and nagar haveli', 'dadra and nagar haveli and daman and diu'),
    ('dadra and nagar haveli and daman and diu', 'dadra and nagar haveli and daman and diu'),
    ('nct of delhi', 'delhi'),
    ('orissa', 'odisha'),
    ('uttaranchal', 'uttarakhand'),
    ('pondicherry', 'puducherry'),
    ('chattisgarh', 'chhattisgarh'),
    ('telengana', 'telangana');


-- =====================================================================
-- 2. CLEAN TABLES
-- =====================================================================

-- 2.1 bills : monthly, one row per state-month
drop table if exists bills;

create table bills as
select
    g.state,
    g.`year`,
    g.`month`,
    str_to_date(concat(g.`year`, '-', lpad(g.`month`, 2, '0'), '-01'), '%Y-%m-%d') as period,
    case when g.`month` >= 4 then g.`year` else g.`year` - 1 end as fy_start,
    concat(
        case when g.`month` >= 4 then g.`year` else g.`year` - 1 end,
        '-',
        right(case when g.`month` >= 4 then g.`year` else g.`year` - 1 end + 1, 2)
    ) as fy,
    g.intra_suppliers,
    g.intra_bills,
    g.intra_assets,
    g.inter_out_suppliers,
    g.inter_out_bills,
    g.inter_out_asset,
    g.inter_in_suppliers,
    g.inter_in_bills,
    g.inter_in_asset
from (
    select
        coalesce(a.state, r.k) as state,
        r.`year`,
        r.`month`,
        sum(r.intra_suplliers) as intra_suppliers,
        sum(r.intra_bill) as intra_bills,
        round(sum(r.intra_assets), 2) as intra_assets,
        sum(r.inter_out_suplliers) as inter_out_suppliers,
        sum(r.inter_out_bill) as inter_out_bills,
        round(sum(r.inter_out_asset), 2) as inter_out_asset,
        sum(r.inter_in_suplliers) as inter_in_suppliers,
        sum(r.inter_in_bill) as inter_in_bills,
        round(sum(r.inter_in_asset), 2) as inter_in_asset
    from (
        select
            w.*,
            trim(replace(replace(replace(replace(replace(
                lower(trim(w.state_name)),
            '*', ''), '(ut)', ''), '-ut', ''), '&', 'and'), '  ', ' ')) as k
        from bill w
    ) r
    left join state_alias a on a.alias = r.k
    where r.k not in ('other territory', 'india')
    group by coalesce(a.state, r.k), r.`year`, r.`month`
) g;

select * from bills limit 5;


-- 2.2 bills_fy : fiscal-year totals, complete (12-month) fiscal years only
drop table if exists bills_fy;

create table bills_fy as
select
    state,
    fy_start,
    fy,
    count(distinct period) as months,
    sum(intra_bills + inter_out_bills + inter_in_bills) as bill_volume,
    round(sum(intra_assets + inter_out_asset + inter_in_asset), 2) as bill_amount,
    round(sum(intra_assets), 2) as intra_amount,
    round(sum(inter_out_asset), 2) as inter_out_amount,
    round(sum(inter_in_asset), 2) as inter_in_amount
from bills
group by state, fy_start, fy
having count(distinct period) = 12;

select * from bills_fy order by state, fy_start limit 10;


-- 2.3 gsdp_clean : one row per state, columns are fiscal years
drop table if exists gsdp_clean;

create table gsdp_clean as
select
    coalesce(a.state, r.k) as state,
    round(sum(r.`2018-19`), 2) as `2018-19`,
    round(sum(r.`2019-20`), 2) as `2019-20`,
    round(sum(r.`2020-21`), 2) as `2020-21`,
    round(sum(r.`2021-22`), 2) as `2021-22`,
    round(sum(r.`2022-23`), 2) as `2022-23`,
    round(sum(r.`2023-24`), 2) as `2023-24`
from (
    select
        g.*,
        trim(replace(replace(replace(replace(replace(
            lower(trim(g.`state/ut`)),
        '*', ''), '(ut)', ''), '-ut', ''), '&', 'and'), '  ', ' ')) as k
    from gsdp g
) r
left join state_alias a on a.alias = r.k
where r.k not in ('other territory', 'india')
group by coalesce(a.state, r.k);

select * from gsdp_clean limit 5;


-- 2.4 population_clean : one row per state, columns are calendar years
drop table if exists population_clean;

create table population_clean as
select
    coalesce(a.state, r.k) as `state`,
    sum(r.`2018`) as `2018`,
    sum(r.`2019`) as `2019`,
    sum(r.`2020`) as `2020`,
    sum(r.`2021`) as `2021`,
    sum(r.`2022`) as `2022`,
    sum(r.`2023`) as `2023`,
    sum(r.`2024`) as `2024`,
    sum(r.`2025`) as `2025`,
    sum(r.`2026`) as `2026`
from (
    select
        p.*,
        trim(replace(replace(replace(replace(replace(
            lower(trim(p.`state/ut`)),
        '*', ''), '(ut)', ''), '-ut', ''), '&', 'and'), '  ', ' ')) as k
    from population p
) r
left join state_alias a on a.alias = r.k
where r.k not in ('other territory', 'india')
group by coalesce(a.state, r.k);

select * from population_clean limit 5;


-- 2.5 gsdp_long : state x fiscal year
drop table if exists gsdp_long;

create table gsdp_long as
select state, 2018 as fy_start, '2018-19' as fy, `2018-19` as gsdp from gsdp_clean
union all
select state, 2019, '2019-20', `2019-20` from gsdp_clean
union all
select state, 2020, '2020-21', `2020-21` from gsdp_clean
union all
select state, 2021, '2021-22', `2021-22` from gsdp_clean
union all
select state, 2022, '2022-23', `2022-23` from gsdp_clean
union all
select state, 2023, '2023-24', `2023-24` from gsdp_clean;


-- 2.6 population_long : state x year (source is in thousands -> people)
-- The 'india' filter wraps the whole union so it applies to every year.
drop table if exists population_long;

create table population_long as
select state, `year`, population
from (
    select state, 2018 as `year`, `2018` * 1000 as population from population_clean
    union all
    select state, 2019, `2019` * 1000 from population_clean
    union all
    select state, 2020, `2020` * 1000 from population_clean
    union all
    select state, 2021, `2021` * 1000 from population_clean
    union all
    select state, 2022, `2022` * 1000 from population_clean
    union all
    select state, 2023, `2023` * 1000 from population_clean
    union all
    select state, 2024, `2024` * 1000 from population_clean
    union all
    select state, 2025, `2025` * 1000 from population_clean
    union all
    select state, 2026, `2026` * 1000 from population_clean
) u
where state != 'india';


-- 2.7 fy_panel : state x fiscal year with bills, GSDP and population together
-- Only fiscal years present in all three sources are kept.
drop table if exists fy_panel;

create table fy_panel as
select
    b.state,
    b.fy_start,
    b.fy,
    p.population,
    g.gsdp,
    b.bill_volume,
    b.bill_amount,
    b.intra_amount,
    b.inter_out_amount,
    b.inter_in_amount,
    round(b.bill_amount / p.population, 4) as per_capita_amount
from bills_fy b
join gsdp_long g
    on g.state = b.state and g.fy_start = b.fy_start
join population_long p
    on p.state = b.state and p.`year` = b.fy_start
where g.gsdp is not null
  and p.population is not null;

select * from fy_panel order by state, fy_start limit 10;


-- =====================================================================
-- 3. JOIN CHECKS (each should return no rows)
-- =====================================================================
select distinct state as in_bills_not_in_gsdp from bills where state not in (select state from gsdp_clean);
select distinct state as in_bills_not_in_population from bills where state not in (select state from population_clean);
select state as in_gsdp_not_in_bills from gsdp_clean where state not in (select state from bills);
select state as in_population_not_in_bills from population_clean where state not in (select state from bills);


-- =====================================================================
-- 4. VIEWS (one per question)
-- =====================================================================

-- Q1. Forecasting: monthly goods amount per state (complete fiscal years)
--     with 3-month and 12-month rolling averages.
drop view if exists forecasting_data;

create view forecasting_data as
with totaled as (
    select
        b.state,
        b.period,
        date_format(b.period, '%Y-%m') as `date`,
        b.fy,
        (b.intra_bills + b.inter_out_bills + b.inter_in_bills) as bill_volume,
        round((b.intra_assets + b.inter_out_asset + b.inter_in_asset), 2) as bill_amount
    from bills b
    join bills_fy f
        on f.state = b.state and f.fy_start = b.fy_start
)
select
    state,
    `date`,
    fy,
    bill_volume,
    bill_amount,
    round(avg(bill_volume) over (partition by state order by period rows between 2 preceding and current row), 2) as avg_bill_3m,
    round(avg(bill_amount) over (partition by state order by period rows between 2 preceding and current row), 2) as avg_amount_3m,
    round(avg(bill_amount) over (partition by state order by period rows between 11 preceding and current row), 2) as avg_amount_12m
from totaled;


-- Q2. Per capita amount gain vs GSDP gain, first to last common fiscal year.
drop view if exists gain_classification;

create view gain_classification as
with window_fy as (
    select min(fy_start) as first_fy, max(fy_start) as last_fy
    from fy_panel
),
ends as (
    select
        p.state,
        max(w.first_fy) as first_fy,
        max(w.last_fy) as last_fy,
        max(case when p.fy_start = w.first_fy then p.per_capita_amount end) as pc_first,
        max(case when p.fy_start = w.last_fy then p.per_capita_amount end) as pc_last,
        max(case when p.fy_start = w.first_fy then p.gsdp end) as gsdp_first,
        max(case when p.fy_start = w.last_fy then p.gsdp end) as gsdp_last
    from fy_panel p
    cross join window_fy w
    group by p.state
),
gains as (
    select
        state,
        concat(first_fy, '-', right(first_fy + 1, 2)) as from_fy,
        concat(last_fy, '-', right(last_fy + 1, 2)) as to_fy,
        round((pc_last - pc_first) / nullif(pc_first, 0) * 100, 2) as per_capita_gain_pct,
        round((gsdp_last - gsdp_first) / nullif(gsdp_first, 0) * 100, 2) as gsdp_gain_pct
    from ends
    where pc_first is not null and pc_last is not null
      and gsdp_first is not null and gsdp_last is not null
)
select
    state,
    from_fy,
    to_fy,
    per_capita_gain_pct,
    gsdp_gain_pct,
    round(per_capita_gain_pct - gsdp_gain_pct, 2) as gain_gap_pct,
    case
        when per_capita_gain_pct > 0 and gsdp_gain_pct > 0 and per_capita_gain_pct > gsdp_gain_pct then 'goods outgrowing economy'
        when per_capita_gain_pct > 0 and gsdp_gain_pct > 0 then 'goods lagging economy'
        when per_capita_gain_pct <= 0 and gsdp_gain_pct > 0 then 'goods falling, economy growing'
        when per_capita_gain_pct > 0 and gsdp_gain_pct <= 0 then 'goods growing, economy falling'
        else 'both falling'
    end as gain_class
from gains;


-- Q3. Clustering features: one row per state, averaged over the common
--     fiscal-year window (states must have every year in the window).
drop view if exists cluster_data;

create view cluster_data as
with window_fy as (
    select min(fy_start) as first_fy, max(fy_start) as last_fy
    from fy_panel
)
select
    p.state,
    round(avg(p.bill_volume), 0) as avg_bill_volume,
    round(avg(p.bill_amount), 2) as avg_bill_amount,
    round(avg(p.bill_amount / p.bill_volume), 2) as avg_amount_per_bill,
    round(avg((p.inter_out_amount + p.inter_in_amount) / p.bill_amount), 4) as inter_state_share,
    round(avg(p.per_capita_amount), 4) as avg_per_capita_amount,
    round(avg(p.bill_amount / p.gsdp), 4) as avg_amount_to_gsdp,
    round(avg(p.gsdp), 2) as avg_gsdp,
    round(avg(p.population), 0) as avg_population,
    round((power(
        max(case when p.fy_start = w.last_fy then p.bill_amount end)
        / nullif(max(case when p.fy_start = w.first_fy then p.bill_amount end), 0),
        1 / nullif(max(w.last_fy - w.first_fy), 0)
    ) - 1) * 100, 2) as amount_cagr_pct
from fy_panel p
cross join window_fy w
group by p.state
having count(*) = max(w.last_fy - w.first_fy + 1);


-- =====================================================================
-- 5. QUICK CHECKS
-- =====================================================================
select * from forecasting_data order by state, `date` limit 10;
select * from gain_classification order by gain_gap_pct desc;
select * from cluster_data;