import 'package:flutter/material.dart';

enum JobApplicationStatus {
  pendiente,
  postulada,
  enEvaluacion,
  seleccionada,
  noSeleccionada;

  String get label => switch (this) {
        JobApplicationStatus.pendiente => 'Pendiente',
        JobApplicationStatus.postulada => 'Postulada',
        JobApplicationStatus.enEvaluacion => 'En evaluación',
        JobApplicationStatus.seleccionada => 'Seleccionada',
        JobApplicationStatus.noSeleccionada => 'No seleccionada',
      };

  String get databaseValue => switch (this) {
        JobApplicationStatus.pendiente => 'pendiente',
        JobApplicationStatus.postulada => 'postulada',
        JobApplicationStatus.enEvaluacion => 'en evaluacion',
        JobApplicationStatus.seleccionada => 'seleccionada',
        JobApplicationStatus.noSeleccionada => 'no seleccionada',
      };

  IconData get icon => switch (this) {
        JobApplicationStatus.pendiente => Icons.hourglass_top_rounded,
        JobApplicationStatus.postulada => Icons.send_rounded,
        JobApplicationStatus.enEvaluacion => Icons.manage_search_rounded,
        JobApplicationStatus.seleccionada => Icons.check_circle_rounded,
        JobApplicationStatus.noSeleccionada => Icons.cancel_rounded,
      };

  Color get color => switch (this) {
        JobApplicationStatus.pendiente => const Color(0xFFF57C00),
        JobApplicationStatus.postulada => const Color(0xFF141E42),
        JobApplicationStatus.enEvaluacion => const Color(0xFF0288D1),
        JobApplicationStatus.seleccionada => const Color(0xFF2E7D32),
        JobApplicationStatus.noSeleccionada => const Color(0xFFC62828),
      };

  static JobApplicationStatus fromDatabaseValue(String value) {
    final normalized = value.trim().toLowerCase();
    return switch (normalized) {
      'pendiente' => JobApplicationStatus.pendiente,
      'postulada' => JobApplicationStatus.postulada,
      'en evaluacion' || 'en_evaluacion' || 'en evaluación' =>
        JobApplicationStatus.enEvaluacion,
      'seleccionada' => JobApplicationStatus.seleccionada,
      'no seleccionada' || 'no_seleccionada' =>
        JobApplicationStatus.noSeleccionada,
      _ => JobApplicationStatus.pendiente,
    };
  }
}
