#include "test-harness.h"
#include <Block.h>
#include <express.h>
#include <stdlib.h>

app_t *initApp(const char *databaseUrl, int databasePoolSize);

test_harness_t *testHarnessFactory() {
  const char *databaseUrl = getenv("TEST_DATABASE_URL");

  __block app_t *app = initApp(databaseUrl, 5);
  int port = 3032;

  test_harness_t *testHarness = malloc(sizeof(test_harness_t));

  testHarness->teardown = Block_copy(^{
    shutdownAndFreeApp(app);
  });

  testHarness->setup = Block_copy(^(void (^callback)()) {
    app->listen(port, ^{
      callback();
    });
  });

  return testHarness;
}
