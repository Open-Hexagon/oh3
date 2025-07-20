#include <string.h>
#include <stdio.h>

typedef struct named_pointer {
	const char* name;
	void* address;
} namedp;

static namedp library_table[] = {
	LIBRARY_TABLES
	{ NULL, NULL }
};

static char error[100] = "\0";

static void* search_named_pointer(namedp* list, const char* name) {
	for (; list->name; list++) {
		if (strcmp(name, list->name) == 0) {
			return list->address;
		}
	}
	snprintf(error, sizeof(error), "could not find '%s'", name);
	return NULL;
}

void* dlopen(const char* filename, int _) {
	return search_named_pointer(library_table, filename);
}

void* dlsym(void* handle, const char* name) {
	return search_named_pointer(handle, name);
}

int dlclose(void* _) {
	return 0;
}

char* dlerror(void) {
	return error;
};
