# rpostgis tests
# These are most basic tests to ensure all functions are working

tryCatch({
library(rpostgis)
library(RPostgreSQL)
drv<-dbDriver("PostgreSQL")
library(sp)
data("meuse")
cred<-scan(".pgpass_rpostgis", what = "character")
conn <- dbConnect(drv, host = cred[1], dbname = cred[2], user = cred[3], password = cred[4])
conn2 <- dbConnect(drv, host = cred[1], dbname = cred[5], user = cred[3], password = cred[4])

# general arguments
new_table <- c("rpostgis","db_test")
ex_table<-c("example_data","relocations_plus")

print(system.time({
# general
pgPostGIS(conn)
pgListGeom(conn)

# retrieval functions
pts<-pgGetGeom(conn, ex_table , geom = "geom")
pts2<-pgGetGeom(conn, ex_table , geom = "geom", clauses = "where id = 'continental' order by time limit 100")
poly<-pgGetGeom(conn2, c("env_data","adm_boundaries"), clauses = "order by nome_com")
lin<-pgGetGeom(conn2,c("env_data","roads"))
bnd<-pgGetBoundary(conn, ex_table)
rast<-pgGetRast(conn2,c("env_data","corine_land_cover"))

# get SRIDs
pgSRID(conn,crs = bnd@proj4string)
pgSRID(conn2,crs = rast@crs)

lin@proj4string<-CRS("+:fakeCRS", doCheckCRSArgs = FALSE)
pgSRID(conn2,crs = lin@proj4string, create.srid = TRUE)

# send data to database
dbSchema(conn,new_table[1])
dbDrop(conn,new_table,type = "table", ifexists = TRUE)
pgInsert(conn,new_table,pts)
pgListGeom(conn)

# drop table
dbDrop(conn, new_table)

# send data to database, no geom
pgInsert(conn,new_table,pts@data)

# send data to database with geom, overwrite, with new ID num
pgInsert(conn,new_table,pts,overwrite = TRUE, new.id = "gid_r")

# test general db functions
dbComment(conn, new_table, comment = "test table for rpostgis.")
dbAddKey(conn, new_table, colname = "gid_r")

dbColumn(conn, new_table, "date2", coltype = "character varying")
dbExecute(conn, "UPDATE rpostgis.db_test SET date2 = time;")

dbAsDate(conn, new_table, "date2", tz = "America/Los_Angeles")
dbTableInfo(conn, new_table, allinfo = TRUE)

dbGetQuery(conn, "SELECT time, date2 FROM rpostgis.db_test LIMIT 1;")
# date2 is 3 hrs later, since displaying in local time (EST)

dbIndex(conn, new_table, colname = "date2")
dbIndex(conn, new_table, colname = "geom", method = "gist")

dbVacuum(conn, new_table, full = TRUE)

# upsert
pts<-pgGetGeom(conn, new_table)
head(pts@data$dummy)
pts@data$dummy <- 12345

pgInsert(conn, new_table, pts, upsert.using = "gid_r")
pts2<-pgGetGeom(conn, new_table)

all.equal(pts,pts2)
# only difference is date2 (tz difference)
pts<-pts2
rm(pts2)

# insert only geom
dbExecute(conn, "ALTER TABLE rpostgis.db_test DROP COLUMN gid_r;")
pts.sponly<-SpatialPoints(pts,proj4string = pts@proj4string)
pgInsert(conn, new_table, pts.sponly)

# pgMakePts
pgInsert(conn, c("rpostgis","meuse"), meuse)
pgMakePts(conn, c("rpostgis","meuse") , colname = "geom_make", srid = 26917, index = TRUE)

# pgMakeStp
alb<-DBI::dbGetQuery(conn,"SELECT * FROM example_data.albatross;")
pgInsert(conn,c("rpostgis","alba"), alb, new.id = "gid_R")
pgMakeStp(conn, c("rpostgis","alba"), colname = "geom_stp", srid = 26917, index = TRUE)

# drop schema
dbDrop(conn, new_table[1], type = "schema", cascade = TRUE)

dbDisconnect(conn)
dbDisconnect(conn2)
rm(pts,pts.sponly,bnd,lin,poly,rast, conn, conn2, drv, alb, meuse, ex_table, new_table, cred)
})
)
print("ALL GOOD!!!")
},
error = function(x) {
  print("errors...")
  print(x)
})