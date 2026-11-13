/// Fuentes entre las que el administrador puede elegir (nombres de Google Fonts).
const kFuenteDefecto = 'Predeterminada';

const kFuentes = <String>[
  kFuenteDefecto,
  'Roboto',
  'Poppins',
  'Lato',
  'Montserrat',
  'Nunito',
  'Open Sans',
  'Raleway',
  'Oswald',
  'Merriweather',
  'Playfair Display',
];

/// Tamaño máximo de cada imagen (se guarda dentro de Firestore, límite 1 MB por documento).
const kMaxBytesImagen = 600 * 1024;
