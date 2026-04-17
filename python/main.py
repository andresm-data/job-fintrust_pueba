# -*- coding:utf-8 -*-
import logging
import sys


# =============================================================================
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s  %(levelname)-8s  %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
log = logging.getLogger(__name__)


# =============================================================================
def main() -> int:
    """
    Ejecuta el pipeline de validación de datos.

    Returns
    -------
    int
        Código de salida del pipeline:
        - 0 si todo salió bien
        - 1 si hubo errores

    Raises
    ------
    ImportError
        Si no se encuentra el módulo 'validacion_gx'
    """
    try:
        import validacion_gx
        return validacion_gx.main()

    except ImportError:
        log.error(
            "No se encontró el módulo 'validacion_gx'. "
            "Asegúrese de que validacion_gx.py está en el mismo directorio."
        )
        return 1


if __name__ == "__main__":
    sys.exit(main())
