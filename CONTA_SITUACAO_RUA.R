library(data.table)
library(stringi)
library(arrow)
library(DBI)
library(duckdb)
library(ggplot2)
library(ggalluvial)


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
    END AS poprua,
    -- 2 = rua rural (rural, terra indígena ou quilombola), 1 = rua urbana, 0 = tem teto
    CASE
      WHEN (p.in_dormir_rua_memb = 1 OR p.in_dormir_albergue_memb = 1)
           AND (f.co_local_domic_fam = 2 OR f.co_indigena_reside_fam = 1
                OR f.in_familia_quilombola_fam = 1)
      THEN 2
      WHEN (p.in_dormir_rua_memb = 1 OR p.in_dormir_albergue_memb = 1)
      THEN 1 ELSE 0
    END AS situacao
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
  SELECT SUM(poprua) AS poprua_202212,
         SUM(CASE WHEN situacao = 1 THEN 1 ELSE 0 END) AS poprua_urbana_202212,
         SUM(CASE WHEN situacao = 2 THEN 1 ELSE 0 END) AS poprua_rural_202212
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
    END AS poprua2,
    -- 2 = rua rural (rural, terra indígena ou quilombola), 1 = rua urbana, 0 = tem teto
    CASE
      WHEN (p.in_dormir_rua_memb = 1 OR p.in_dormir_albergue_memb = 1)
           AND (f.co_local_domic_fam = 2 OR f.co_indigena_reside_fam = 1
                OR f.in_familia_quilombola_fam = 1)
      THEN 2
      WHEN (p.in_dormir_rua_memb = 1 OR p.in_dormir_albergue_memb = 1)
      THEN 1 ELSE 0
    END AS situacao2
  FROM cadus2 AS p
  LEFT JOIN cadufam2 AS f
    ON p.co_familiar_fam = f.co_familiar_fam;
"))

n2 <- dbGetQuery(con, "
  SELECT SUM(poprua2) AS poprua_202606,
         SUM(CASE WHEN situacao2 = 1 THEN 1 ELSE 0 END) AS poprua_urbana_202606,
         SUM(CASE WHEN situacao2 = 2 THEN 1 ELSE 0 END) AS poprua_rural_202606
  FROM cadu_merge2
  ;
")


# Full join por CPF: uma linha por pessoa. CPFs nulos são descartados (nunca casariam
# e virariam "Invisível" falso). MAX dá prioridade à situação de rua se o CPF repetir
# (situacao: 0 < 1 urbana < 2 rural).
dbExecute(con, glue::glue("
  CREATE OR REPLACE VIEW cadu_merge_f AS
  SELECT
    COALESCE(l.nu_cpf_pessoa, r.nu_cpf_pessoa) AS nu_cpf_pessoa,
    l.poprua,
    l.situacao,
    r.poprua2,
    r.situacao2
  FROM (
    SELECT nu_cpf_pessoa, MAX(poprua) AS poprua, MAX(situacao) AS situacao
    FROM cadu_merge
    WHERE nu_cpf_pessoa IS NOT NULL
    GROUP BY nu_cpf_pessoa
  ) AS l
  FULL JOIN (
    SELECT nu_cpf_pessoa, MAX(poprua2) AS poprua2, MAX(situacao2) AS situacao2
    FROM cadu_merge2
    WHERE nu_cpf_pessoa IS NOT NULL
    GROUP BY nu_cpf_pessoa
  ) AS r
    ON l.nu_cpf_pessoa = r.nu_cpf_pessoa;
"))

#---- SANKEY: TRAJETÓRIA ENTRE DEZ/2022 E JUN/2026 ------###
# Obs.: "Invisível" no período 2 significa que a pessoa saiu do cadastro ou ficou
# desatualizada (fora dos filtros de data/estado cadastral), não que se tornou invisível.

fluxos <- setDT(dbGetQuery(con, "
  SELECT
    CASE situacao  WHEN 2 THEN 'Rua rural' WHEN 1 THEN 'Rua urbana' WHEN 0 THEN 'Tem teto' ELSE 'Invisível' END AS periodo_1,
    CASE situacao2 WHEN 2 THEN 'Rua rural' WHEN 1 THEN 'Rua urbana' WHEN 0 THEN 'Tem teto' ELSE 'Invisível' END AS periodo_2,
    COUNT(*) AS n
  FROM cadu_merge_f
  GROUP BY 1, 2
  ORDER BY 1, 2;
"))
print(fluxos)

rua <- c("Rua urbana", "Rua rural")
niveis <- c(rua, "Tem teto", "Invisível")
fluxos_rua <- fluxos[periodo_1 %in% rua | periodo_2 %in% rua]
fluxos_rua[, `:=`(
  periodo_1 = factor(periodo_1, levels = niveis),
  periodo_2 = factor(periodo_2, levels = niveis)
)]

sankey <- ggplot(fluxos_rua, aes(axis1 = periodo_1, axis2 = periodo_2, y = n)) +
  geom_alluvium(aes(fill = periodo_1), width = 1/6) +
  geom_stratum(width = 1/6) +
  geom_text(stat = "stratum", aes(label = after_stat(stratum)), size = 3) +
  scale_x_discrete(limits = c("dez/2022", "jun/2026"), expand = c(.1, .1)) +
  scale_y_continuous(labels = scales::label_number(big.mark = ".")) +
  labs(fill = "dez/2022", y = "Pessoas (CPF)",
       title = "Trajetória das pessoas em situação de rua no CadÚnico") +
  theme_minimal()

print(sankey)
ggsave("sankey_poprua.png", sankey, width = 9, height = 6, dpi = 300, bg = "white")









