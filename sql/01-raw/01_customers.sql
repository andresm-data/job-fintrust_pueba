CREATE SCHEMA IF NOT EXISTS raw_fintrust;

CREATE TABLE
    IF NOT EXISTS raw_fintrust.customers (
        customer_id STRING,
        full_name STRING,
        city STRING,
        segment STRING,
        monthly_income NUMERIC,
        created_at DATE
    );

INSERT INTO
    raw_fintrust.customers
VALUES
    (
        'C001',
        'Ana Torres',
        'Bogota',
        'Mass Market',
        4200000,
        '2024-11-10'
    ),
    (
        'C002',
        'Luis Perez',
        'Medellin',
        'Premium',
        8600000,
        '2024-12-02'
    ),
    (
        'C003',
        'Maria Rojas',
        'Cali',
        'Mass Market',
        3800000,
        '2024-12-15'
    ),
    (
        'C004',
        'Carlos Diaz',
        'Bogota',
        'SME',
        12400000,
        '2025-01-03'
    ),
    (
        'C005',
        'Laura Gomez',
        'Barranquilla',
        'Mass Market',
        3100000,
        '2025-01-18'
    ),
    (
        'C006',
        'Sofia Marin',
        'Medellin',
        'Premium',
        9700000,
        '2025-01-21'
    ),
    (
        'C007',
        'Andres Ruiz',
        'Bogota',
        'Mass Market',
        4500000,
        '2025-02-01'
    ),
    (
        'C008',
        'Juliana Vega',
        'Cali',
        'SME',
        13300000,
        '2025-02-10'
    ),
    (
        'C009',
        'Fernando Lopez',
        'Bogota',
        'Mass Market',
        3900000,
        '2024-06-15'
    ),
    (
        'C010',
        'Diana Castro',
        'Medellin',
        'Premium',
        11200000,
        '2024-07-20'
    ),
    (
        'C011',
        'Ricardo Mora',
        'Bucaramanga',
        'Mass Market',
        3500000,
        '2024-08-05'
    ),
    (
        'C012',
        'Camila Herrera',
        'Bogota',
        'SME',
        15800000,
        '2024-08-22'
    ),
    (
        'C013',
        'Jorge Sanchez',
        'Cali',
        'Mass Market',
        4100000,
        '2024-09-10'
    ),
    (
        'C014',
        'Valentina Rios',
        'Barranquilla',
        'Premium',
        8900000,
        '2024-09-18'
    ),
    (
        'C015',
        'Miguel Angel Parra',
        'Bogota',
        'Mass Market',
        4800000,
        '2024-10-01'
    ),
    (
        'C016',
        'Natalia Gutierrez',
        'Medellin',
        'SME',
        14200000,
        '2024-10-12'
    ),
    (
        'C017',
        'David Ospina',
        'Cartagena',
        'Mass Market',
        3200000,
        '2024-10-25'
    ),
    (
        'C018',
        'Paola Mendez',
        'Bogota',
        'Premium',
        10500000,
        '2024-11-03'
    ),
    (
        'C019',
        'Sebastian Vargas',
        'Cali',
        'Mass Market',
        3700000,
        '2024-11-15'
    ),
    (
        'C020',
        'Angela Restrepo',
        'Medellin',
        'SME',
        16500000,
        '2024-11-28'
    ),
    (
        'C021',
        'Oscar Jimenez',
        'Barranquilla',
        'Mass Market',
        2800000,
        '2024-12-05'
    ),
    (
        'C022',
        'Marcela Duarte',
        'Bogota',
        'Premium',
        9200000,
        '2024-12-18'
    ),
    (
        'C023',
        'Ivan Cardenas',
        'Bucaramanga',
        'Mass Market',
        4300000,
        '2025-01-05'
    ),
    (
        'C024',
        'Catalina Munoz',
        'Cali',
        'SME',
        13800000,
        '2025-01-12'
    ),
    (
        'C025',
        'Alejandro Bernal',
        'Bogota',
        'Mass Market',
        4600000,
        '2025-01-20'
    ),
    (
        'C026',
        'Luisa Fernanda Gil',
        'Medellin',
        'Premium',
        12100000,
        '2025-01-25'
    ),
    (
        'C027',
        'Pedro Ramirez',
        'Cartagena',
        'Mass Market',
        3400000,
        '2025-02-03'
    ),
    (
        'C028',
        'Monica Salazar',
        'Barranquilla',
        'SME',
        11900000,
        '2025-02-08'
    ),
    (
        'C029',
        'Gustavo Alvarez',
        'Bogota',
        'Mass Market',
        5100000,
        '2025-02-14'
    ),
    (
        'C030',
        'Carolina Pineda',
        'Cali',
        'Premium',
        8300000,
        '2025-02-20'
    ),
    (
        'C031',
        'Ernesto Mejia',
        'Medellin',
        'Mass Market',
        3600000,
        '2025-02-25'
    ),
    (
        'C032',
        'Isabel Navarro',
        'Bogota',
        'SME',
        17200000,
        '2025-03-01'
    ),
    (
        'C033',
        'Roberto Cifuentes',
        'Bucaramanga',
        'Mass Market',
        4000000,
        '2025-03-05'
    ),
    (
        'C034',
        'Daniela Acosta',
        'Barranquilla',
        'Premium',
        9800000,
        '2025-03-08'
    ),
    (
        'C035',
        'Fabian Ortiz',
        'Bogota',
        'Mass Market',
        4400000,
        '2025-03-12'
    );