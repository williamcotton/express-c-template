ifneq (,$(wildcard ./.env))
	include .env
	export
endif

PLATFORM := $(shell sh -c 'uname -s 2>/dev/null | tr 'a-z' 'A-Z'')

CC = clang
PROFDATA = llvm-profdata
COV = llvm-cov
TIDY = clang-tidy
FORMAT = clang-format

ifeq ($(PLATFORM),DARWIN)
	CC = $(shell brew --prefix llvm)/bin/clang
	PROFDATA = $(shell brew --prefix llvm)/bin/profdata
	COV = $(shell brew --prefix llvm)/bin/llvm-cov
	TIDY = $(shell brew --prefix llvm)/bin/clang-tidy
	FORMAT = $(shell brew --prefix llvm)/bin/clang-format
endif

TARGET = app
CFLAGS = $(shell cat compile_flags.txt | tr '\n' ' ')
CFLAGS += -DBUILD_ENV=$(BUILD_ENV) -lcurl $(shell pkg-config --libs libpq) -I$(shell pg_config --includedir) -I/usr/local/include -L/usr/local/lib -lexpress
DEV_CFLAGS = -g -O0
TEST_CFLAGS = -Werror -ltape
SRC = $(filter-out app/main.c, $(wildcard app/*.c))
TEST_SRC = $(filter-out test/test.c, $(wildcard test/*.c)) $(wildcard test/*/*.c)
BUILD_DIR = build
PROD_CFLAGS = -Ofast

ifeq ($(PLATFORM),LINUX)
	CFLAGS += -lm -lBlocksRuntime -ldispatch -lbsd -luuid -lpthread
else ifeq ($(PLATFORM),DARWIN)
	DEV_CFLAGS += -fsanitize=address,undefined,implicit-conversion,float-divide-by-zero,local-bounds,nullability
endif

all: $(TARGET)

.PHONY: $(TARGET)
$(TARGET):
	mkdir -p $(BUILD_DIR)
	$(CC) -o $(BUILD_DIR)/$@ app/main.c $(SRC) $(CFLAGS) $(DEV_CFLAGS) -DERR_STACKTRACE

$(TARGET)-prod: app/embeddedFiles.h
	mkdir -p $(BUILD_DIR)
	$(CC) -o $(BUILD_DIR)/$(TARGET) app/main.c $(SRC) $(CFLAGS) $(PROD_CFLAGS) -DEMBEDDED_FILES=1

.PHONY: test
test: test-database-create
	mkdir -p $(BUILD_DIR)
	$(CC) -o $(BUILD_DIR)/$@ test/test.c $(TEST_SRC) $(SRC) $(CFLAGS) $(TEST_CFLAGS) $(DEV_CFLAGS)
	$(BUILD_DIR)/$@

test-database-create:
	-dbmate -e TEST_DATABASE_URL create

database-create:
	-dbmate -e DATABASE_URL create

test-coverage-output:
	mkdir -p $(BUILD_DIR)
	mkdir -p $(BUILD_DIR)/coverage
	$(CC) -o $(BUILD_DIR)/$@ test/test.c $(TEST_SRC) $(SRC) $(CFLAGS) $(TEST_CFLAGS) $(DEV_CFLAGS) -fprofile-instr-generate -fcoverage-mapping
	LLVM_PROFILE_FILE="build/test.profraw" $(BUILD_DIR)/$@
	$(PROFDATA) merge -sparse build/test.profraw -o build/test.profdata
	$(COV) show $(BUILD_DIR)/$@ -instr-profile=$(BUILD_DIR)/test.profdata -ignore-filename-regex="/test/"

test-coverage-html:
	mkdir -p $(BUILD_DIR)
	mkdir -p $(BUILD_DIR)/coverage
	$(CC) -o $(BUILD_DIR)/$@ test/test.c $(TEST_SRC) $(SRC) $(CFLAGS) $(TEST_CFLAGS) $(DEV_CFLAGS) -fprofile-instr-generate -fcoverage-mapping
	LLVM_PROFILE_FILE="build/test.profraw" $(BUILD_DIR)/$@
	$(PROFDATA) merge -sparse build/test.profraw -o build/test.profdata
	$(COV) show $(BUILD_DIR)/$@ -instr-profile=$(BUILD_DIR)/test.profdata -ignore-filename-regex="/test/" -format=html > $(BUILD_DIR)/code-coverage.html

test-coverage:
	mkdir -p $(BUILD_DIR)
	mkdir -p $(BUILD_DIR)/coverage
	$(CC) -o $(BUILD_DIR)/$@ test/test.c $(TEST_SRC) $(SRC) $(CFLAGS) $(TEST_CFLAGS) $(DEV_CFLAGS) -fprofile-instr-generate -fcoverage-mapping
	LLVM_PROFILE_FILE="build/test.profraw" $(BUILD_DIR)/$@
	$(PROFDATA) merge -sparse build/test.profraw -o build/test.profdata
	$(COV) report $(BUILD_DIR)/$@ -instr-profile=$(BUILD_DIR)/test.profdata -ignore-filename-regex="/test/"

lint:
ifeq ($(PLATFORM),LINUX)
	$(TIDY) --checks=-clang-analyzer-security.insecureAPI.DeprecatedOrUnsafeBufferHandling -warnings-as-errors=* app/main.c
else ifeq ($(PLATFORM),DARWIN)
	$(TIDY) -warnings-as-errors=* app/main.c
endif

format:
	$(FORMAT) --dry-run --Werror $(SRC)

clean:
	rm -rf $(BUILD_DIR)
	mkdir -p $(BUILD_DIR)

$(TARGET)-watch: $(TARGET) $(TARGET)-run-background
	fswatch --event Updated app/ .env | xargs -n1 -I{} watch.sh $(TARGET)

$(TARGET)-run-background: $(TARGET)-kill
	$(BUILD_DIR)/$(TARGET) &

$(TARGET)-kill:
	kill.sh $(TARGET)

test-watch:
	make --no-print-directory test || :
	fswatch --event Updated -o test/*.c test/*.h src/ | xargs -n1 -I{} make --no-print-directory test

build-test-trace:
	mkdir -p $(BUILD_DIR)
	$(CC) -o $(BUILD_DIR)/test test/test.c $(TEST_SRC) $(SRC) $(TEST_CFLAGS) $(CFLAGS) -g -O0
ifeq ($(PLATFORM),DARWIN)
	codesign -s - -v -f --entitlements test/debug.plist $(BUILD_DIR)/test
endif

test-leaks: build-test-trace test-database-create
ifeq ($(PLATFORM),LINUX)
	valgrind --tool=memcheck --leak-check=full --suppressions=/usr/local/share/express.supp --suppressions=test/app.supp --gen-suppressions=all --error-exitcode=1 --num-callers=30 -s $(BUILD_DIR)/test
else ifeq ($(PLATFORM),DARWIN)
	leaks --atExit -- $(BUILD_DIR)/test
endif

test-analyze:
	clang --analyze $(SRC) $(shell cat compile_flags.txt | tr '\n' ' ') -I$(shell pg_config --includedir) -Xanalyzer -analyzer-output=text -Xanalyzer -analyzer-checker=core,deadcode,nullability,optin,osx,security,unix,valist -Xanalyzer -analyzer-disable-checker -Xanalyzer security.insecureAPI.DeprecatedOrUnsafeBufferHandling

test-threads:
	mkdir -p $(BUILD_DIR)
	$(CC) -o $(BUILD_DIR)/$@ $(TEST_SRC) $(SRC) $(CFLAGS) $(TEST_CFLAGS) -fsanitize=thread
	$(BUILD_DIR)/$@

manual-test-trace: build-test-trace
	SLEEP_TIME=5 RUN_X_TIMES=10 $(BUILD_DIR)/test

$(TARGET)-trace:
	$(CC) -o $(BUILD_DIR)/$(TARGET) $(SRC) $(CFLAGS) -g -O0
ifeq ($(PLATFORM),DARWIN)
	codesign -s - -v -f --entitlements test/debug.plist $(BUILD_DIR)/$(TARGET)
endif

$(TARGET)-prod-trace: app/embeddedFiles.h
	$(CC) -o $(BUILD_DIR)/$(TARGET) $(SRC) $(CFLAGS) $(PROD_CFLAGS) -DEMBEDDED_FILES=1
ifeq ($(PLATFORM),DARWIN)
	codesign -s - -v -f --entitlements test/debug.plist $(BUILD_DIR)/$(TARGET)
endif

$(TARGET)-analyze:
	$(CC) --analyze $(SRC) $(CFLAGS) -Xclang -analyzer-output=text

.PHONY: app/embeddedFiles.h
app/embeddedFiles.h:
	embed.sh $@ public/* app/views/* >> $@

.env:
	cp default.env .env
