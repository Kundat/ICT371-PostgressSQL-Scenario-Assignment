DROP TABLE IF EXISTS dispensing_records;
DROP TABLE IF EXISTS medicines;
CREATE TABLE medicines (
 medicine_id SERIAL PRIMARY KEY,
 medicine_name VARCHAR(60) NOT NULL,
 stock_quantity INT NOT NULL CHECK (stock_quantity >= 0)
);
CREATE TABLE dispensing_records (
 record_id SERIAL PRIMARY KEY,
 medicine_id INT NOT NULL REFERENCES medicines(medicine_id),
 student_number VARCHAR(20) NOT NULL,
 quantity INT NOT NULL CHECK (quantity > 0),
 status VARCHAR(10) NOT NULL DEFAULT 'DISPENSED'
 CHECK (status IN ('DISPENSED', 'REVERSED'))
);

INSERT INTO medicines (medicine_name, stock_quantity) VALUES
 ('Paracetamol 500mg', 100),
 ('Amoxicillin 250mg', 8),
 ('Ibuprofen 200mg', 0);
 SELECT * FROM medicines ORDER BY medicine_id;


DO $$
DECLARE
 rec RECORD;
BEGIN
 FOR rec IN SELECT medicine_name, stock_quantity FROM medicines ORDER BY medicine_id LOOP
 IF rec.stock_quantity = 0 THEN
 RAISE NOTICE '% : OUT OF STOCK', rec.medicine_name;
 ELSIF rec.stock_quantity <= 10 THEN
 RAISE NOTICE '% : LOW on stock (%)', rec.medicine_name, rec.stock_quantity;
 ELSE
 RAISE NOTICE '% : sufficiently stocked (%)', rec.medicine_name, rec.stock_quantity;
 END IF;
 END LOOP;
END $$;

DO $$
DECLARE
 day_no INT := 1;
BEGIN
 WHILE day_no <= 3 LOOP
 RAISE NOTICE 'Stock review day %', day_no;
 day_no := day_no + 1;
 END LOOP;
 FOR insp_no IN 1..3 LOOP
 RAISE NOTICE 'Shelf inspection number %', insp_no;
 END LOOP;
END $$;

CREATE OR REPLACE PROCEDURE dispense_medicine(
p_medicine_id INT, p_student_number VARCHAR, p_quantity INT)
LANGUAGE plpgsql
AS $$
DECLARE
 v_stock INT;
BEGIN
 IF p_quantity IS NULL OR p_quantity <= 0 THEN
 RAISE EXCEPTION 'Invalid quantity: % (must be greater than zero)', p_quantity
 USING ERRCODE = '22023';
 END IF;
SELECT stock_quantity INTO v_stock
 FROM medicines WHERE medicine_id = p_medicine_id FOR UPDATE;
 IF NOT FOUND THEN
 RAISE EXCEPTION 'Medicine % does not exist', p_medicine_id;
 END IF;
 IF v_stock < p_quantity THEN
 RAISE EXCEPTION 'Insufficient stock: % available, % requested', v_stock, p_quantity;
 END IF;
 UPDATE medicines SET stock_quantity = stock_quantity - p_quantity
 WHERE medicine_id = p_medicine_id;
 INSERT INTO dispensing_records (medicine_id, student_number, quantity)
 VALUES (p_medicine_id, p_student_number, p_quantity);
 RAISE NOTICE 'Dispensed % unit(s) of medicine % to student %',
 p_quantity, p_medicine_id, p_student_number;
END $$;

DO $$
BEGIN
 CALL dispense_medicine(1, 'S3001', 20); -- valid
 CALL dispense_medicine(2, 'S3002', 3); -- valid
 BEGIN
 CALL dispense_medicine(2, 'S3003', 50); -- exceeds stock
 EXCEPTION WHEN OTHERS THEN
 RAISE NOTICE 'Dispensing rejected: %', SQLERRM;
 END;
END $$;

SELECT * FROM medicines ORDER BY medicine_id;

SELECT * FROM dispensing_records ORDER BY record_id;


CREATE OR REPLACE PROCEDURE reverse_dispensing(p_record_id INT)
LANGUAGE plpgsql
AS $$
DECLARE
 v_medicine_id INT;
 v_qty INT;
BEGIN
 UPDATE dispensing_records SET status = 'REVERSED'
 WHERE record_id = p_record_id AND status = 'DISPENSED'
 RETURNING medicine_id, quantity INTO v_medicine_id, v_qty;
 IF NOT FOUND THEN
 RAISE NOTICE 'Record % is not active or does not exist - stock not restored', p_record_id;
 ELSE
 UPDATE medicines SET stock_quantity = stock_quantity + v_qty
 WHERE medicine_id = v_medicine_id;
 RAISE NOTICE 'Record % reversed - % unit(s) restored', p_record_id, v_qty;
 END IF;
END $$;
CALL reverse_dispensing(1); -- restores stock
CALL reverse_dispensing(1); -- second call: stock not restored again


SELECT * FROM medicines ORDER BY medicine_id;

SELECT * FROM dispensing_records ORDER BY record_id;


DO $$
DECLARE
 v_threshold INT := 10;
 cur_low CURSOR (p_limit INT) FOR
 SELECT medicine_id, medicine_name, stock_quantity
 FROM medicines WHERE stock_quantity < p_limit
 ORDER BY stock_quantity;
 rec RECORD;
BEGIN
 OPEN cur_low(v_threshold);
 LOOP
 FETCH cur_low INTO rec;
 EXIT WHEN NOT FOUND;
 RAISE NOTICE 'Below threshold (%): % (id %) - % in stock',
 v_threshold, rec.medicine_name, rec.medicine_id, rec.stock_quantity;
 END LOOP;
 CLOSE cur_low;
END $$;
DO $$
BEGIN
 CALL dispense_medicine(1, 'S3004', -5);
EXCEPTION
 WHEN invalid_parameter_value THEN
 RAISE NOTICE 'Handled invalid input: %', SQLERRM;
END $$;

SELECT medicine_id, medicine_name, stock_quantity FROM medicines ORDER BY medicine_id;
SELECT record_id, medicine_id, student_number, quantity, status
FROM dispensing_records ORDER BY record_id;
