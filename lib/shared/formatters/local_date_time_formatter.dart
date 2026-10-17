/// Display a local timestamp through whole seconds without changing stored precision.
String localDateTimeToSeconds(DateTime value) =>
    value.toLocal().toString().split('.').first;
