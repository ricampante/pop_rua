library(data.table)
library(stringi)
library(arrow)
library(DBI)
library(duckdb)


con <- dbConnect(duckdb::duckdb())

dbExecute(con, glue::glue("
  CREATE OR REPLACE VIEW cadufam AS
  SELECT co_familiar_fam, dt_cadastro_fam,  co_local_domic_fam, co_est_cadastral_fam,
  cd_ibge_cadastro, co_indigena_reside_fam, in_familia_quilombola_fam, in_parc_mds_fam, co_especie_domic_fam,
  marc_pbf
  FROM parquet_scan('{cadu}cadunico_fam_202212.parquet')
  WHERE dt_atualizacao_fam >= DATE '2020-12-01' AND co_est_cadastral_fam = 3;
"))

total_rows <- dbGetQuery(con, "SELECT COUNT(*) AS total FROM cadufam")
print(total_rows)

# AND co_condicao_cadastro_fam = '1' AND in_cadastro_valido_fam = '1'

dbExecute(con, glue::glue("
  CREATE OR REPLACE VIEW cadus AS
  SELECT co_familiar_fam, cd_ibge_cadastro, dt_nasc_pessoa, co_est_cadastral_memb, co_deficiencia_memb,
  dt_cadastramento_memb,
  in_dormir_rua_memb, in_dormir_albergue_memb, in_dormir_outro_memb, nu_cpf_pessoa
  FROM parquet_scan('{cadu}cadunico_pes_202212.parquet')
  WHERE  co_est_cadastral_memb = 3;
"))


total_rows2 <- dbGetQuery(con, "SELECT COUNT(*) AS total FROM cadus")
print(total_rows2)

# Acampados, ou desabrigados/desalojados, ou dorme na rua ou em albergue na área urbana

# dbExecute(con, glue::glue("
#   CREATE OR REPLACE VIEW cadu_merge AS
#   SELECT
#     p.nu_cpf_pessoa,
#     f.co_familiar_fam,
#     CASE
#       WHEN (  f.in_parc_mds_fam = 303
#         OR f.in_parc_mds_fam = 401
#         OR f.co_especie_domic_fam = 2
#         OR f.co_especie_domic_fam = 3
#         OR p.in_dormir_rua_memb = 1
#         OR p.in_dormir_albergue_memb = 1 )
#         AND co_local_domic_fam = 1
#       THEN 1 ELSE 0
#     END AS poprua
#   FROM cadus AS p
#   LEFT JOIN cadufam AS f
#     ON p.co_familiar_fam = f.co_familiar_fam;
# "))

dbExecute(con, glue::glue("
  CREATE OR REPLACE VIEW cadu_merge AS
  SELECT
    p.nu_cpf_pessoa,
    p.co_familiar_fam,
    CASE
      WHEN (in_dormir_rua_memb = 1 OR in_dormir_albergue_memb = 1)
      THEN 1 ELSE 0
    END AS poprua
  FROM cadus AS p
  LEFT JOIN cadufam AS f
    ON p.co_familiar_fam = f.co_familiar_fam;
"))

# dbExecute(con, glue::glue("
#   CREATE OR REPLACE VIEW cadu_rua AS
#   SELECT
#     nu_cpf_pessoa, dt_cadastramento_memb,
#     CASE
#       WHEN (
#         in_dormir_rua_memb = 1
#          )
#       THEN 1 ELSE 0
#     END AS poprua
#   FROM cadus;
# "))

n0 <- dbGetQuery(con, "
  SELECT SUM(poprua) AS poprua_202212 
  FROM cadu_merge
  ;
")

# amostra_10pct <- dbGetQuery(con, "
#   SELECT * 
#   FROM cadu_merge
#   USING SAMPLE 1 PERCENT (reservoir);
# ")

#---- DADOS MAIS RECENTES: JUNHO DE 2026 ------###
dbExecute(con, glue::glue("
  CREATE OR REPLACE VIEW cadufam2 AS
  SELECT co_familiar_fam, dt_cadastro_fam,  co_local_domic_fam, co_est_cadastral_fam,
  cd_ibge_cadastro, co_indigena_reside_fam, in_familia_quilombola_fam, in_parc_mds_fam, co_especie_domic_fam,
  marc_pbf
  FROM parquet_scan('{cadu}cadunico_fam_202606.parquet')
  WHERE dt_atualizacao_fam >= DATE '2024-06-01' AND co_est_cadastral_fam = 3;
"))

total_rows3 <- dbGetQuery(con, "SELECT COUNT(*) AS total FROM cadufam2")
print(total_rows3)

# AND co_condicao_cadastro_fam = '1' AND in_cadastro_valido_fam = '1'

dbExecute(con, glue::glue("
  CREATE OR REPLACE VIEW cadus2 AS
  SELECT co_familiar_fam, cd_ibge_cadastro, dt_nasc_pessoa, co_est_cadastral_memb, co_deficiencia_memb,
  dt_cadastramento_memb,
  in_dormir_rua_memb, in_dormir_albergue_memb, in_dormir_outro_memb, nu_cpf_pessoa
  FROM parquet_scan('{cadu}cadunico_pes_202606.parquet')
  WHERE  co_est_cadastral_memb = 3;
"))


total_rows4 <- dbGetQuery(con, "SELECT COUNT(*) AS total FROM cadus2")
print(total_rows4)



dbExecute(con, glue::glue("
  CREATE OR REPLACE VIEW cadu_merge2 AS
  SELECT
    p.nu_cpf_pessoa,
    p.co_familiar_fam,
    p.dt_cadastramento_memb,
    f.dt_cadastro_fam,
    CASE
      WHEN (in_dormir_rua_memb = 1 OR in_dormir_albergue_memb = 1)
      THEN 1 ELSE 0
    END AS poprua2
  FROM cadus2 AS p
  LEFT JOIN cadufam2 AS f
    ON p.co_familiar_fam = f.co_familiar_fam;
"))

n2 <- dbGetQuery(con, "
  SELECT SUM(poprua2) AS poprua_202606 
  FROM cadu_merge2
  ;
")


dbExecute(con, glue::glue("
  CREATE OR REPLACE VIEW cadu_merge_f AS
  SELECT(*)
  FROM cadu_merge AS l
  LEFT JOIN cadu_merge2 AS r
    ON l.co_familiar_fam = r.co_familiar_fam;
"))









