import 'local_store.dart';

// Used where there is no browser (widget tests): values live in memory and
// no `online` event ever comes.
LocalStore createLocalStore() => MemoryLocalStore();

void Function() listenForOnline(void Function() onOnline) => () {};
