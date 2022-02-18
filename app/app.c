#include <cJSON/cJSON.h>
#include <express.h>
#include <middleware/mustache-middleware.h>
#include <middleware/postgres-middleware.h>
#include <stdlib.h>

#ifdef EMBEDDED_FILES
#include "embeddedFiles.h"
#else
embedded_files_data_t embeddedFiles = {0};
#endif // EMBEDDED_FILES

app_t *initApp(const char *databaseUrl, int databasePoolSize) {
  app_t *app = express();

  /* Load static files */
  char *staticFilesPath = cwdFullPath("public");
  app->use(expressStatic("public", staticFilesPath, embeddedFiles));

  /* Mustache middleware */
  app->use(mustacheMiddleware("app/views", embeddedFiles));

  /* Postgres middleware */
  postgres_connection_t *postgres =
      initPostgressConnection(databaseUrl, databasePoolSize);
  app->use(postgresMiddlewareFactory(postgres));

  /* Health check */
  app->get("/healthz", ^(UNUSED request_t *req, response_t *res) {
    res->send("OK");
  });

  /* Front page */
  app->get("/", ^(UNUSED request_t *req, response_t *res) {
    /* Query the database */
    pg_t *pg = req->m("pg");
    PGresult *pgres =
        pg->exec("SELECT CONCAT($1::varchar, $2::varchar, $3::varchar)",
                 "express", "-", "c");
    const char *title = PQgetvalue(pgres, 0, 0);

    /* Build up json */
    cJSON *json = cJSON_CreateObject();
    cJSON_AddStringToObject(json, "content", title);

    /* Render the template */
    res->render("index", json);

    /* Clean up */
    PQclear(pgres);
  });

  /* Clean up */
  app->cleanup(Block_copy(^{
    free(staticFilesPath);
    freePostgresConnection(postgres);
  }));

  return app;
}
