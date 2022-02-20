#include <Block.h>
#include <dotenv-c/dotenv.h>
#include <express.h>
#include <stdio.h>
#include <stdlib.h>
#include <string/string.h>
#include <tape/tape.h>

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wshadow"
#pragma clang diagnostic ignored "-Wunused-parameter"
#pragma clang diagnostic ignored "-Wunused-variable"

void expressTests(tape_t *t);

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

void runTests(int runAndExit, test_harness_t *testHarness) {
  tape_t *test = tape();

  int testStatus = test->test("express", ^(tape_t *t) {
    t->clearState();

    t->test("front page", ^(tape_t *t) {
      t->ok("text", t->get("/")->contains("express-c"));
    });

    t->strEqual("healthz", t->get("/healthz"), "OK");
  });

  Block_release(test->test);
  free(test);

  if (runAndExit) {
    testHarness->teardown();
    exit(testStatus);
  }
}

int main() {
  env_load(".", false);

  int runXTimes = getenv("RUN_X_TIMES") ? atoi(getenv("RUN_X_TIMES")) : 1;
  int sleepTime = getenv("SLEEP_TIME") ? atoi(getenv("SLEEP_TIME")) : 0;

  sleep(sleepTime);

  test_harness_t *testHarness = testHarnessFactory();

  testHarness->setup(^{
    for (int i = 0; i < runXTimes; i++) {
      runTests(runXTimes == 1, testHarness);
    }
    if (runXTimes > 1)
      exit(0);
  });
}

#pragma clang diagnostic pop
