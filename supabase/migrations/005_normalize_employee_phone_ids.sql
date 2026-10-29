update public.employees
set phone = case
  when normalized_phone ~ '^216[0-9]{8}$' then right(normalized_phone, 8)
  else normalized_phone
end
from (
  select
    id,
    case
      when regexp_replace(coalesce(phone, ''), '\D', '', 'g') like '00%'
        then substr(regexp_replace(coalesce(phone, ''), '\D', '', 'g'), 3)
      else regexp_replace(coalesce(phone, ''), '\D', '', 'g')
    end as normalized_phone
  from public.employees
) normalized
where public.employees.id = normalized.id
  and public.employees.phone is not null;

update public.employees
set phone = null
where phone = '';
