--Checking Duplicate values
select *, count(*) from dbo.demand group by date, demandlevel, location, producttype
having count(*)>1

--Creating CTC for selecting Duplicate values
with del_dup as
		(select *, ROW_NUMBER() over(Partition By date, demandlevel, location, producttype order by productType) as Dup from dbo.demand)

--Deleting duplicate values
delete from del_dup where Dup>1

alter table dbo.demand
alter column date date

select * from dbo.demand