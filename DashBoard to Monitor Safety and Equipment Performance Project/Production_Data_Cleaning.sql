--Visualizing data
select * from dbo.prod_data


--Checking Duplicate values
select *, count(*) from dbo.prod_data group by productiondate, productionlevel, location, producttype
having count(*)>1

--Creating CTC for selecting Duplicate values
with del_dup as
		(select *, ROW_NUMBER() over(Partition By productiondate, productionlevel, location, producttype order by productType) as Dup from dbo.prod_data)

--Deleting duplicate values
delete from del_dup where Dup>1


--Invalid Product Type
select * from dbo.prod_data where ProductType not in ('Associated Natural Gas Liquids', 'Crude Oil', 'Natural Gas')

--Deleting Invalid Product Type
delete from dbo.prod_data where ProductType not in ('Associated Natural Gas Liquids', 'Crude Oil', 'Natural Gas')

--Deleting Null Product Type
delete from dbo.prod_data where ProductType is NULL


--Creating CTE for detecting Outliers
with prod_stats as
		(select Location, ProductType, AVG(ProductionLevel) as Avg_ProdLvl,
		STDEV(ProductionLevel) as Std_Dev
		from dbo.prod_data group by ProductType, location),

prod_outlier as
		(select prod.location, prod.ProductionLevel, prod.ProductType, (prod.productionlevel - stat.avg_prodlvl) / stat.Std_Dev as ZScore
		from prod_stats stat join dbo.prod_data prod on stat.productType = prod.productType),

outlierDetect as
		(select *, (Case when zscore>1.96 or zscore<-1.96 then 1 else 0 end) as OutlierDet
		from prod_outlier)

--Selecting the rows having outliers
select * from
dbo.prod_data prod join outlierDetect od on prod.productionlevel = od.productionlevel
and prod.productType = od.productType and prod.location = od.location
where OutlierDet = 1

--Deleting the outliers
delete dbo.prod_data from dbo.prod_data prod join outlierDetect od on prod.productionlevel = od.productionlevel
and prod.productType = od.productType and prod.location = od.location
where OutlierDet = 1


--Looking the data having location = null
select * from dbo.prod_data where Location is null

--Deleting the data having location = null
delete from dbo.prod_data where Location is null


--Calculating Avg
with avg_cte as
		(select Location, ProductType, AVG(ProductionLevel) as Avg_ProdLvl
		from dbo.prod_data group by ProductType, location)

--Mean Imputation 
update prod
set prod.productionlevel = od.Avg_ProdLvl
from dbo.prod_data prod join avg_cte od on 
prod.productType = od.productType and prod.location = od.location
where prod.productionlevel is null

--Checking whether the rows are updated or not
select od.Location, od.ProductType, prod.productionlevel, ISNULL(prod.productionlevel, avg_prodlvl) from avg_cte od join dbo.prod_data prod on 
prod.productType = od.productType and prod.location = od.location

alter table dbo.prod_data
alter column productiondate date


