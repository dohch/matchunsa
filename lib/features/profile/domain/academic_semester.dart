abstract final class AcademicSemester {
  static const options = <int>[
    1,
    2,
    3,
    4,
    5,
    6,
    7,
    8,
    9,
    10,
    11,
    12,
    13,
    14,
  ];

  static String label(int semester) {
    return switch (semester) {
      1 || 3 => '$semester.er semestre',
      _ => '$semester.º semestre',
    };
  }
}
