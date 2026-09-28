import 'package:flutter/material.dart';

/// Permite abrir telas de fora de um widget (ex.: quando o horário de um
/// medicamento chega ou o usuário toca numa notificação).
final GlobalKey<NavigatorState> navegadorKey = GlobalKey<NavigatorState>();
