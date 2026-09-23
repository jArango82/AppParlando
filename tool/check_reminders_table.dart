// Quick check: table schedule_reminders reachable with anon key.
import 'dart:convert';
import 'dart:io';

void main() async {
  final env = File('env.txt').readAsLinesSync();
  String? url;
  String? key;
  for (final line in env) {
    if (line.startsWith('INSFORGE_URL=')) url = line.substring(13).trim();
    if (line.startsWith('INSFORGE_ANON_KEY=')) key = line.substring(18).trim();
  }
  if (url == null || key == null) {
    stderr.writeln('Missing INSFORGE_URL or INSFORGE_ANON_KEY');
    exit(1);
  }

  final uri = Uri.parse('$url/api/database/records/schedule_reminders?limit=1');
  final client = HttpClient();
  final req = await client.getUrl(uri);
  req.headers.set('Authorization', 'Bearer $key');
  req.headers.set('Content-Type', 'application/json');
  final res = await req.close();
  final body = await res.transform(utf8.decoder).join();
  stdout.writeln('HTTP ${res.statusCode}');
  if (res.statusCode == 200) {
    stdout.writeln('OK: tabla schedule_reminders accesible');
    stdout.writeln('rows sample: ${body.length > 120 ? '${body.substring(0, 120)}…' : body}');
  } else {
    stdout.writeln('FAIL body: $body');
  }
  client.close();
}
