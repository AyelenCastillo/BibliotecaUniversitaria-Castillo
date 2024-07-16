DROP DATABASE IF EXISTS biblioteca_model;
CREATE DATABASE biblioteca_model;
USE biblioteca_model;

-- Tablas
CREATE TABLE autores (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(255) NOT NULL,
    nacionalidad VARCHAR(100)
);

CREATE TABLE categorias (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL
);

CREATE TABLE libros (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    titulo VARCHAR(255) NOT NULL,
    autor_id INT UNSIGNED NOT NULL,
    categoria_id INT UNSIGNED NOT NULL,
    ano_publicacion INT,
    ISBN VARCHAR(17),
    cantidad_stock INT DEFAULT 5,
    FOREIGN KEY (autor_id) REFERENCES autores(id),
    FOREIGN KEY (categoria_id) REFERENCES categorias(id)
);

CREATE TABLE libros_autores (
    libro_id INT UNSIGNED NOT NULL,
    autor_id INT UNSIGNED NOT NULL,
    PRIMARY KEY (libro_id, autor_id),
    FOREIGN KEY (libro_id) REFERENCES libros(id),
    FOREIGN KEY (autor_id) REFERENCES autores(id)
);

CREATE TABLE estudiantes (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(255) NOT NULL,
    email VARCHAR(255) UNIQUE,
    telefono VARCHAR(20)
);

CREATE TABLE profesores (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(255) NOT NULL,
    email VARCHAR(255) UNIQUE,
    telefono VARCHAR(20)
);

CREATE TABLE prestamos_estudiantes (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    libro_id INT UNSIGNED NOT NULL,
    estudiante_id INT UNSIGNED NOT NULL,
    fecha_prestamo DATE,
    fecha_devolucion DATE,
    CONSTRAINT fk_libro_prestamo_estudiantes
        FOREIGN KEY (libro_id) REFERENCES libros(id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_estudiante
        FOREIGN KEY (estudiante_id) REFERENCES estudiantes(id),
    UNIQUE KEY (libro_id, estudiante_id)
);

CREATE TABLE prestamos_profesores (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    libro_id INT UNSIGNED NOT NULL,
    profesor_id INT UNSIGNED NOT NULL,
    fecha_prestamo DATE,
    fecha_devolucion DATE,
    CONSTRAINT fk_libro_prestamo_profesores
        FOREIGN KEY (libro_id) REFERENCES libros(id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_profesor
        FOREIGN KEY (profesor_id) REFERENCES profesores(id),
    UNIQUE KEY (libro_id, profesor_id)
);

-- tigger necesario para hacer la comprobacion para las condiciones en los prestamos de los libros
/*tiggers*/
DELIMITER //
CREATE TRIGGER before_insert_prestamo_estudiante
BEFORE INSERT ON prestamos_estudiantes
FOR EACH ROW
BEGIN
    DECLARE prestamos_count INT;
    
    SELECT COUNT(*)
    INTO prestamos_count
    FROM prestamos_estudiantes
    WHERE estudiante_id = NEW.estudiante_id AND libro_id = NEW.libro_id AND fecha_devolucion IS NULL;
    
    IF prestamos_count > 0 THEN
        SET NEW.estudiante_id = NULL;
    END IF;
    
    SELECT COUNT(*)
    INTO prestamos_count
    FROM prestamos_estudiantes
    WHERE estudiante_id = NEW.estudiante_id AND fecha_devolucion IS NULL;
    
    IF prestamos_count >= 2 THEN
        SET NEW.estudiante_id = NULL;
    END IF;
    
END //

CREATE TRIGGER before_insert_prestamo_profesor
BEFORE INSERT ON prestamos_profesores
FOR EACH ROW
BEGIN
    DECLARE prestamos_count INT;
    
    SELECT COUNT(*)
    INTO prestamos_count
    FROM prestamos_profesores
    WHERE profesor_id = NEW.profesor_id AND libro_id = NEW.libro_id AND fecha_devolucion IS NULL;
    
    IF prestamos_count > 0 THEN
        SET NEW.profesor_id = NULL;
    END IF;
    
    SELECT COUNT(*)
    INTO prestamos_count
    FROM prestamos_profesores
    WHERE profesor_id = NEW.profesor_id AND fecha_devolucion IS NULL;
    
    IF prestamos_count >= 4 THEN
        SET NEW.profesor_id = NULL;
    END IF;
    
END //


DELIMITER ;


-- Datos ficticios generados por IA 
/*Autores*/
INSERT INTO autores (nombre, nacionalidad) VALUES
    ('Juan Martínez', 'Argentino'),
    ('Emily Johnson', 'Estadounidense'),
    ('Luis Rodríguez', 'Mexicano'),
    ('Sophie Dubois', 'Francesa'),
    ('David Brown', 'Británico'),
    ('Satoshi Tanaka', 'Japonés'),
    ('Maria Silva', 'Brasileña'),
    ('Anastasia Ivanova', 'Rusa'),
    ('Carlos Sánchez', 'Español'),
    ('Ali Khan', 'Pakistani');
    
/*Categorias*/
INSERT INTO categorias (nombre) VALUES
    ('Economía'),
    ('Programación'),
    ('Historia del Arte'),
    ('Matemáticas'),
    ('Literatura'),
    ('Ingeniería'),
    ('Química'),
    ('Psicología'),
    ('Derecho'),
    ('Filosofía');
/*Libros*/
INSERT INTO libros (titulo, autor_id, categoria_id, ano_publicacion, ISBN, cantidad_stock) VALUES
    ('Introducción a la Economía', 1, 1, 2019, '978-607-32-2551-0', 5),
    ('Fundamentos de Programación en C', 2, 2, 2020, '978-607-32-2552-7', 5),
    ('Historia del Arte', 3, 3, 2015, '978-84-376-2032-3', 5),
    ('Cálculo Diferencial e Integral', 4, 4, 2018, '978-607-32-2553-4', 5),
    ('Literatura Universal', 5, 5, 2017, '978-84-376-2033-0', 5),
    ('Ingeniería de Software', 6, 6, 2021, '978-607-32-2554-1', 5),
    ('Química Orgánica', 7, 7, 2016, '978-84-376-2034-7', 5),
    ('Psicología del Desarrollo', 8, 8, 2019, '978-607-32-2555-8', 5),
    ('Derecho Internacional', 9, 9, 2020, '978-84-376-2035-4', 5),
    ('Filosofía Política', 10, 10, 2018, '978-607-32-2556-5', 5);
/*Libros_autores*/
INSERT INTO libros_autores (libro_id, autor_id) VALUES
    (1, 1), 
    (1, 2), 
    (2, 2),
    (3, 3),
    (4, 4),
    (5, 5),
    (6, 6),
    (7, 7),
    (8, 8),
    (9, 9),
    (10, 10);
/*Estudiantes*/
INSERT INTO estudiantes (nombre, email, telefono) VALUES
    ('Ana García', 'ana.garcia@example.com', '123-456-7890'),
    ('Carlos López', 'carlos.lopez@example.com', '234-567-8901'),
    ('María Martínez', 'maria.martinez@example.com', '345-678-9012'),
    ('Juan Rodríguez', 'juan.rodriguez@example.com', '456-789-0123');
/*Profesores*/
INSERT INTO profesores (nombre, email, telefono) VALUES
    ('Dr. Roberto Pérez', 'roberto.perez@example.com', '567-890-1234'),
    ('Dra. Laura Fernández', 'laura.fernandez@example.com', '678-901-2345');