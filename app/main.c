#include <dotenv-c/dotenv.h>
#include <express.h>
#include <stdlib.h>

app_t *initApp(const char *databaseUrl, int databasePoolSize);

int main() {
  /* Load .env file */
  env_load(".", false);

  /* Environment variables */
  char *PORT = getenv("PORT");
  int port = PORT ? atoi(PORT) : 3000;
  char *DATABASE_URL = getenv("DATABASE_URL");
  char *DATABASE_POOL_SIZE = getenv("DATABASE_POOL_SIZE");
  int databasePoolSize = DATABASE_POOL_SIZE ? atoi(DATABASE_POOL_SIZE) : 5;
  const char *databaseUrl =
      DATABASE_URL ? DATABASE_URL : "postgresql://localhost/app-development";

  app_t *app = initApp(databaseUrl, databasePoolSize);

  /* Close app on Ctrl+C */
  signal(SIGINT, SIG_IGN);
  dispatch_source_t sig_src = dispatch_source_create(
      DISPATCH_SOURCE_TYPE_SIGNAL, SIGINT, 0, dispatch_get_main_queue());
  dispatch_source_set_event_handler(sig_src, ^{
    app->closeServer();
    exit(0);
  });
  dispatch_resume(sig_src);

  app->listen(port, ^{
    printf("express-c app listening at http://localhost:%d\n", port);
    writePid("server.pid");
  });
}
