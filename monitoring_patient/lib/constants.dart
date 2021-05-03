import 'package:socket_io_client/socket_io_client.dart' as IO;

const appName = 'Monitoring Patient';
const mainURL = '';
const fileLimit = 25;
final IO.Socket socket = IO.io(mainURL, <String, dynamic>{
  'transports': ['websocket'],
  'extraHeaders': {'Access-Control-Allow-Origin': '*'},
});
final role = "admin";
