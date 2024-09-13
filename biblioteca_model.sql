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
    ISBN VARCHAR(20),
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

CREATE TABLE usuarios (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(255) NOT NULL,
    email VARCHAR(255) UNIQUE,
    telefono VARCHAR(20),
    tipo ENUM('estudiante', 'profesor') NOT NULL
);

CREATE TABLE prestamos (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    libro_id INT UNSIGNED NOT NULL,
    usuario_id INT UNSIGNED NOT NULL,
    fecha_prestamo DATE,
    fecha_devolucion DATE,
    CONSTRAINT fk_libro_prestamo
        FOREIGN KEY (libro_id) REFERENCES libros(id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_usuario_prestamo
        FOREIGN KEY (usuario_id) REFERENCES usuarios(id),
    UNIQUE KEY (libro_id, usuario_id)
);

-- Tablas de auditoría
CREATE TABLE auditoria_libros (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    libro_id INT UNSIGNED,
    titulo VARCHAR(255) NOT NULL,
    autor_id INT UNSIGNED NOT NULL,
    categoria_id INT UNSIGNED NOT NULL,
    ano_publicacion INT,
    ISBN VARCHAR(17),
    cantidad_stock INT DEFAULT 5,
    accion ENUM('INSERT', 'UPDATE', 'DELETE') NOT NULL,
    fecha TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    usuario VARCHAR(255),
    FOREIGN KEY (libro_id) REFERENCES libros(id)
);


CREATE TABLE auditoria_usuarios (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    usuario_id INT UNSIGNED,
    nombre_usuario VARCHAR(255),
    email VARCHAR(255),
    telefono VARCHAR(20),
    accion ENUM('INSERT', 'UPDATE', 'DELETE') NOT NULL,
    fecha TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    usuario VARCHAR(255),
    FOREIGN KEY (usuario_id) REFERENCES usuarios(id)
);

-- Funciones
DELIMITER //
CREATE FUNCTION verificar_prestamo_estudiante(p_usuario_id INT)
RETURNS BOOLEAN
DETERMINISTIC
BEGIN
    DECLARE total_prestamos INT;
    
    SELECT COUNT(*)
    INTO total_prestamos
    FROM prestamos
    WHERE usuario_id = p_usuario_id
    AND fecha_devolucion IS NULL
    AND (SELECT tipo FROM usuarios WHERE id = p_usuario_id) = 'estudiante';
    
    IF total_prestamos < 2 THEN
        RETURN TRUE;
    ELSE
        RETURN FALSE;
    END IF;
END //

CREATE FUNCTION verificar_prestamo_profesor(p_usuario_id INT)
RETURNS BOOLEAN
DETERMINISTIC
BEGIN
    DECLARE total_prestamos INT;
    
    SELECT COUNT(*)
    INTO total_prestamos
    FROM prestamos
    WHERE usuario_id = p_usuario_id
    AND fecha_devolucion IS NULL
    AND (SELECT tipo FROM usuarios WHERE id = p_usuario_id) = 'profesor';
    
    IF total_prestamos < 4 THEN
        RETURN TRUE;
    ELSE
        RETURN FALSE;
    END IF;
END //

DELIMITER ;

-- Stored Procedures
DELIMITER //

CREATE PROCEDURE realizar_prestamo(
    IN p_libro_id INT,
    IN p_usuario_id INT,
    IN p_fecha_prestamo DATE
)
BEGIN
    DECLARE es_valido BOOLEAN;

    IF (SELECT cantidad_stock FROM libros WHERE id = p_libro_id) <= 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'El libro no está disponible en stock.';
    END IF;

    IF (SELECT tipo FROM usuarios WHERE id = p_usuario_id) = 'estudiante' THEN
        SET es_valido = verificar_prestamo_estudiante(p_usuario_id);
    ELSE
        SET es_valido = verificar_prestamo_profesor(p_usuario_id);
    END IF;

    IF es_valido = FALSE THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'El usuario ha alcanzado el límite de libros permitidos en préstamo.';
    END IF;

    INSERT INTO prestamos (libro_id, usuario_id, fecha_prestamo)
    VALUES (p_libro_id, p_usuario_id, p_fecha_prestamo);

    UPDATE libros
    SET cantidad_stock = cantidad_stock - 1
    WHERE id = p_libro_id;
END //

DELIMITER ;

DELIMITER //

CREATE PROCEDURE devolver_libro(
    IN p_libro_id INT,
    IN p_usuario_id INT
)
BEGIN
    DECLARE fecha_prestamo DATE;

    SELECT fecha_prestamo INTO fecha_prestamo
	FROM prestamos as p
    WHERE libro_id = p_libro_id
    AND usuario_id = p_usuario_id
    AND fecha_devolucion IS NULL;

    IF fecha_prestamo IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'El libro no está en préstamo con este usuario.';
    END IF;

    UPDATE prestamos
    SET fecha_devolucion = CURRENT_DATE
    WHERE libro_id = p_libro_id
    AND usuario_id = p_usuario_id
    AND fecha_devolucion IS NULL;

    UPDATE libros
    SET cantidad_stock = cantidad_stock + 1
    WHERE id = p_libro_id;
END //

DELIMITER ;

DELIMITER //

CREATE PROCEDURE obtener_historial_prestamos (
    IN p_usuario_id INT UNSIGNED
)
BEGIN
    SELECT p.id AS prestamo_id, l.titulo AS libro_titulo, p.fecha_prestamo, p.fecha_devolucion
    FROM prestamos p
    JOIN libros l ON p.libro_id = l.id
    WHERE p.usuario_id = p_usuario_id;
END //

DELIMITER ;

-- Triggers
-- Triggers de auditoría para libros
DELIMITER //

CREATE TRIGGER after_insert_libro
AFTER INSERT ON libros
FOR EACH ROW
BEGIN
    INSERT INTO auditoria_libros (libro_id, titulo, autor_id, categoria_id, ano_publicacion, ISBN, cantidad_stock, accion, usuario, fecha)
    VALUES (NEW.id, NEW.titulo, NEW.autor_id, NEW.categoria_id, NEW.ano_publicacion, NEW.ISBN, NEW.cantidad_stock, 'INSERT', USER(), NOW());
END //

CREATE TRIGGER after_update_libro
AFTER UPDATE ON libros
FOR EACH ROW
BEGIN
    INSERT INTO auditoria_libros (libro_id, titulo, autor_id, categoria_id, ano_publicacion, ISBN, cantidad_stock, accion, usuario, fecha)
    VALUES (NEW.id, NEW.titulo, NEW.autor_id, NEW.categoria_id, NEW.ano_publicacion, NEW.ISBN, NEW.cantidad_stock, 'UPDATE', USER(), NOW());
END //

CREATE TRIGGER after_delete_libro
AFTER DELETE ON libros
FOR EACH ROW
BEGIN
    INSERT INTO auditoria_libros (libro_id, titulo, autor_id, categoria_id, ano_publicacion, ISBN, cantidad_stock, accion, usuario, fecha)
    VALUES (OLD.id, OLD.titulo, OLD.autor_id, OLD.categoria_id, OLD.ano_publicacion, OLD.ISBN, OLD.cantidad_stock, 'DELETE', USER(), NOW());
END //

-- Triggers de auditoría para usuarios
CREATE TRIGGER after_insert_usuario
AFTER INSERT ON usuarios
FOR EACH ROW
BEGIN
    INSERT INTO auditoria_usuarios (usuario_id, nombre_usuario, email, telefono, accion, usuario, fecha)
    VALUES (NEW.id, NEW.nombre, NEW.email, NEW.telefono, 'INSERT', USER(), NOW());
END //

CREATE TRIGGER after_update_usuario
AFTER UPDATE ON usuarios
FOR EACH ROW
BEGIN
    INSERT INTO auditoria_usuarios (usuario_id, nombre_usuario, email, telefono, accion, usuario, fecha)
    VALUES (NEW.id, NEW.nombre, NEW.email, NEW.telefono, 'UPDATE', USER(), NOW());
END //

CREATE TRIGGER after_delete_usuario
AFTER DELETE ON usuarios
FOR EACH ROW
BEGIN
    INSERT INTO auditoria_usuarios (usuario_id, nombre_usuario, email, telefono, accion, usuario, fecha)
    VALUES (OLD.id, OLD.nombre, OLD.email, OLD.telefono, 'DELETE', USER(), NOW());
END //

-- Trigger para verificar condiciones de préstamo
CREATE TRIGGER before_insert_prestamo
BEFORE INSERT ON prestamos
FOR EACH ROW
BEGIN
    DECLARE es_valido BOOLEAN;
	DECLARE cantidad_libros INT;
    
	SELECT cantidad_stock INTO cantidad_libros
    FROM libros
    WHERE id = NEW.libro_id;
    
    IF cantidad_libros <= 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'El libro no está disponible en stock.';
    END IF;
    
    IF (SELECT tipo FROM usuarios WHERE id = NEW.usuario_id) = 'estudiante' THEN
        SET es_valido = verificar_prestamo_estudiante(NEW.usuario_id);
    ELSE
        SET es_valido = verificar_prestamo_profesor(NEW.usuario_id);
    END IF;

    IF es_valido = FALSE THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'El usuario ha alcanzado el límite de libros permitidos en préstamo.';
    END IF;
END //

DELIMITER ;

-- Vistas
CREATE VIEW vista_libros AS
SELECT
    l.id AS libro_id,
    l.titulo,
    a.nombre AS autor,
    c.nombre AS categoria,
    l.ano_publicacion,
    l.ISBN,
    l.cantidad_stock
FROM
    libros l
    JOIN autores a ON l.autor_id = a.id
    JOIN categorias c ON l.categoria_id = c.id;

CREATE VIEW vista_usuarios_prestamos AS
SELECT
    u.id AS usuario_id,
    u.nombre,
    u.email,
    u.telefono,
    u.tipo,
    COUNT(p.id) AS prestamos_activos
FROM
    usuarios u
    LEFT JOIN prestamos p ON u.id = p.usuario_id AND p.fecha_devolucion IS NULL
GROUP BY
    u.id;

CREATE VIEW vista_prestamos_activos AS
SELECT
    p.id AS prestamo_id,
    l.titulo AS libro,
    u.nombre AS usuario,
    p.fecha_prestamo
FROM
    prestamos p
    JOIN libros l ON p.libro_id = l.id
    JOIN usuarios u ON p.usuario_id = u.id
WHERE
    p.fecha_devolucion IS NULL;

CREATE VIEW vista_auditoria_libros AS
SELECT
    al.id AS auditoria_id,
    al.libro_id,
    l.titulo AS libro,
    al.ISBN,
    al.accion,
    al.fecha,
    al.usuario
FROM
    auditoria_libros al
    JOIN libros l ON al.libro_id = l.id;

CREATE VIEW vista_auditoria_usuarios AS
SELECT
    au.id AS auditoria_id,
    au.usuario_id,
    u.nombre AS usuario,
    au.email,
    au.telefono,
    au.accion,
    au.fecha,
    au.usuario AS usuario_auditoria
FROM
    auditoria_usuarios au
    JOIN usuarios u ON au.usuario_id = u.id;
-- Creacion de usuarios (DCL)
/* Crear el administrador
CREATE USER 'administrador'@'localhost' IDENTIFIED BY 'administrador1';
GRANT ALL PRIVILEGES ON biblioteca_model.* TO 'administrador'@'localhost';
FLUSH PRIVILEGES;

-- Crear el usuario para bibliotecarios
CREATE USER 'bibliotecario1'@'localhost' IDENTIFIED BY 'bibliotecario1';
CREATE USER 'bibliotecario2'@'localhost' IDENTIFIED BY 'bibliotecari02';
GRANT SELECT, INSERT, UPDATE, DELETE ON biblioteca_model.libros TO 'bibliotecario1'@'localhost';
GRANT SELECT, INSERT, UPDATE, DELETE ON biblioteca_model.prestamos TO 'bibliotecario1'@'localhost';
GRANT SELECT, INSERT, UPDATE, DELETE ON biblioteca_model.libros TO 'bibliotecario2'@'localhost';
GRANT SELECT, INSERT, UPDATE, DELETE ON biblioteca_model.prestamos TO 'bibliotecario2'@'localhost';
FLUSH PRIVILEGES;
*/
-- Ver los usuarios creados arriba
SHOW GRANTS FOR 'administrador'@'localhost';
SHOW GRANTS FOR 'bibliotecario1'@'localhost';
SHOW GRANTS FOR 'bibliotecario2'@'localhost';

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
    ('Filosofía Política', 10, 10, 2018, '978-607-32-2556-5', 5),
    ('Métodos Numéricos', 1, 1, 2016, '978-0-12-407716-6', 5),
    ('Ingeniería Química', 3, 7, 2015, '978-0-07-182510-3', 5),
    ('Bases de Datos Avanzadas', 8, 2, 2021, '978-1-4493-6102-9', 5),
    ('Análisis de Algoritmos', 4, 1, 2018, '978-0-13-213075-1', 5),
    ('Introducción a la Programación', 2, 2, 2020, '978-0-13-215100-9', 5),
    ('Circuitos Eléctricos', 9, 8, 2017, '978-0-07-338057-5', 5),
    ('Programación en Java', 5, 2, 2019, '978-0-13-469472-6', 5),
    ('Electromagnetismo', 6, 4, 2016, '978-0-471-47133-5', 5),
    ('Técnicas de Machine Learning', 7, 2, 2022, '978-1-119-10339-3', 5),
    ('Diseño Digital', 10, 6, 2020, '978-0-13-214240-7', 5);

/*Usuarios*/
INSERT INTO usuarios (nombre, email, telefono, tipo) VALUES
    ('Ana García', 'ana.garcia@example.com', '123-456-7890', 'estudiante'),
    ('Carlos López', 'carlos.lopez@example.com', '234-567-8901', 'estudiante'),
    ('María Martínez', 'maria.martinez@example.com', '345-678-9012', 'estudiante'),
    ('Juan Rodríguez', 'juan.rodriguez@example.com', '456-789-0123', 'estudiante'),
    ('Dr. Roberto Pérez', 'roberto.perez@example.com', '567-890-1234', 'profesor'),
    ('Dra. Laura Fernández', 'laura.fernandez@example.com', '678-901-2345', 'profesor'),
     ('Luis Gómez', 'luis.gomez@example.com', '123-456-7890', 'estudiante'),
    ('Clara Mendoza', 'clara.mendoza@example.com', '234-567-8901', 'estudiante'),
    ('Mario Ruiz', 'mario.ruiz@example.com', '345-678-9012', 'estudiante'),
    ('Elena Castro', 'elena.castro@example.com', '456-789-0123', 'estudiante'),
    ('Sergio Ortega', 'sergio.ortega@example.com', '567-890-1234', 'estudiante'),
    ('Dra. Sara López', 'sara.lopez@example.com', '678-901-2345', 'profesor'),
    ('Dr. Javier González', 'javier.gonzalez@example.com', '789-012-3456', 'profesor'),
    ('Dra. Natalia Pérez', 'natalia.perez@example.com', '890-123-4567', 'profesor'),
    ('Dr. Miguel Torres', 'miguel.torres@example.com', '901-234-5678', 'profesor'),
    ('Dr. Oscar Medina', 'oscar.medina@example.com', '012-345-6789', 'profesor'),
    ('Ana Muñoz', 'ana.munoz@example.com', '123-789-4560', 'estudiante'),
    ('Pablo Rojas', 'pablo.rojas@example.com', '234-890-5671', 'estudiante'),
    ('Lucía Hernández', 'lucia.hernandez@example.com', '345-901-6782', 'estudiante'),
    ('Alberto Vargas', 'alberto.vargas@example.com', '456-012-7893', 'estudiante');
  
  INSERT INTO prestamos (libro_id, usuario_id, fecha_prestamo) VALUES
    (5, 7, '2024-08-05'),
    (3, 8, '2024-08-06'),
    (2, 9, '2024-08-07'),
    (10, 10, '2024-08-08'),
    (6, 11, '2024-08-09'),
    (9, 12, '2024-08-10'),
    (8, 13, '2024-08-11'),
    (7, 14, '2024-08-12'),
    (1, 15, '2024-08-13'),
    (4, 16, '2024-08-14'),
    (5, 17, '2024-08-15'),
    (2, 18, '2024-08-16'),
    (6, 19, '2024-08-17'),
    (9, 20, '2024-08-18'),
    (3, 4, '2024-08-19'),
	(3, 6, '2024-08-19');
-- Detona apropocito el mensaje de error
/* INSERT INTO prestamos (libro_id, usuario_id, fecha_prestamo)
VALUES (5,1, '2024-08-01'); */


-- Consultas para la generacion del reporte
-- reporte prestamos activos 
SELECT * 
FROM vista_prestamos_activos;

-- reporte usuarios y prestamos 
SELECT * 
FROM vista_usuarios_prestamos
ORDER BY prestamos_activos DESC;

-- reporte stock de libros
SELECT * 
FROM vista_libros
WHERE cantidad_stock > 0;

