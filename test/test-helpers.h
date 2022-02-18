char *curl(char *cmd);
char *curlGet(char *url);
char *curlGetHeaders(char *url);
char *curlDelete(char *url);
char *curlPost(char *url, char *data);
char *curlPut(char *url, char *data);
char *curlPatch(char *url, char *data);
void sendData(char *data);
void clearState();
void randomString(char *str, size_t size);
