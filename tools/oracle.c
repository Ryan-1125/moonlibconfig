/* Original test adapter. Linked to external LGPL libconfig only for local tests. */
#include <stdio.h>
#include <string.h>
#include <libconfig.h>

static void quoted(const char *s) {
  const unsigned char *p = (const unsigned char *)s;
  putchar('"');
  while (*p) { printf("%02x", *p); ++p; }
  putchar('"');
}
static void tree(const config_setting_t *s) {
  int t = config_setting_type(s), i, count;
  const char *names[] = {"none", "group", "integer", "integer64", "float", "string", "boolean", "array", "list"};
  printf("[\"%s\",", names[t]);
  switch (t) {
  case CONFIG_TYPE_INT: printf("\"%d\"", config_setting_get_int(s)); break;
  case CONFIG_TYPE_INT64: printf("\"%lld\"", config_setting_get_int64(s)); break;
  case CONFIG_TYPE_FLOAT: printf("\"%.17g\"", config_setting_get_float(s)); break;
  case CONFIG_TYPE_BOOL: printf("%s", config_setting_get_bool(s) ? "true" : "false"); break;
  case CONFIG_TYPE_STRING: quoted(config_setting_get_string(s)); break;
  default:
    count = config_setting_length(s); putchar('[');
    for (i = 0; i < count; ++i) {
      const config_setting_t *v = config_setting_get_elem(s, i);
      if (i) putchar(',');
      if (t == CONFIG_TYPE_GROUP) { putchar('['); quoted(config_setting_name(v)); putchar(','); }
      tree(v);
      if (t == CONFIG_TYPE_GROUP) putchar(']');
    }
    putchar(']');
  }
  putchar(']');
}
static void normalize_formats(config_setting_t *s) {
  int i;
  config_setting_set_format(s, CONFIG_FORMAT_DEFAULT);
  for (i = 0; i < config_setting_length(s); ++i)
    normalize_formats(config_setting_get_elem(s, i));
}
int main(int argc, char **argv) {
  config_t config;
  if (argc < 2) return 3;
  config_init(&config);
  if (!config_read_file(&config, argv[1])) {
    fprintf(stderr, "%d: %s\n", config_error_line(&config), config_error_text(&config));
    config_destroy(&config); return 2;
  }
  tree(config_root_setting(&config)); putchar('\n');
  config_set_float_precision(&config, 17);
  config_set_option(&config, CONFIG_OPTION_ALLOW_SCIENTIFIC_NOTATION, CONFIG_TRUE);
  normalize_formats(config_root_setting(&config));
  if (argc > 2 && !config_write_file(&config, argv[2])) { config_destroy(&config); return 4; }
  config_destroy(&config); return 0;
}
