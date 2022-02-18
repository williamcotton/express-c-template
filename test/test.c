#include "tape.h"
#include "test-harness.h"
#include "test-helpers.h"
#include <Block.h>
#include <dotenv-c/dotenv.h>
#include <express.h>
#include <stdio.h>
#include <stdlib.h>
#include <string/string.h>

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wshadow"
#pragma clang diagnostic ignored "-Wunused-parameter"
#pragma clang diagnostic ignored "-Wunused-variable"

void expressTests(tape_t *t);

void runTests(int runAndExit, test_harness_t *testHarness) {
  tape_t *test = tape();

  int testStatus = test->test("express", ^(tape_t *t) {
    clearState();

    t->test("front page", ^(tape_t *t) {
      char *frontPage = curlGet("/");
      string_t *frontPageString = string(frontPage);
      t->ok("text", frontPageString->indexOf("express-c") != -1);
      free(frontPage);
      frontPageString->free();
    });

    t->strEqual("healthz", curlGet("/healthz"), "OK");
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
