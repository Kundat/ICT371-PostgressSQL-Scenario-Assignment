DROP TABLE IF EXISTS book_loans;
DROP TABLE IF EXISTS books;
//creating tables
CREATE TABLE books (
book_id SERIAL PRIMARY KEY, 
title VARCHAR(100) NOT NULL,
available_copies INT NOT NULL CHECK (available_copies >=0)
);
//creating bookloans tables
CREATE TABLE book_loans (
loan_id SERIAL PRIMARY KEY,
book_id INT NOT NULL REFERENCES books(book_id), 
student_number VARCHAR(20) NOT NULL,    
quantity INT NOT NULL CHECK (quantity > 0),   
loan_status VARCHAR(10) NOT NULL DEFAULT 'ACTIVE' 
            CHECK (loan_status IN ('ACTIVE', 'RETURNED'))
);
//insertion
INSERT INTO books (title, available_copies) VALUES  
('Database Systems', 5), 
('Operating Systems', 2), 
('Computer Networks', 0);
SELECT * FROM  books ORDER BY book_id;
//IF ELESE ELSIF 
DO $$
DECLARE
 rec RECORD;
BEGIN
 FOR rec IN SELECT title, available_copies FROM books ORDER BY book_id LOOP
 IF rec.available_copies = 0 THEN
 RAISE NOTICE '% : UNAVAILABLE (0 copies)', rec.title;
 ELSIF rec.available_copies <= 2 THEN
 RAISE NOTICE '% : LOW on copies (%)', rec.title, rec.available_copies;
 ELSE
 RAISE NOTICE '% : sufficiently stocked (%)', rec.title, rec.available_copies;
 END IF;
 END LOOP;
END $$;

DO $$
DECLARE
 reminder_no INT := 1;
BEGIN
 WHILE reminder_no <= 3 LOOP
 RAISE NOTICE 'Overdue reminder number: %', reminder_no;
 reminder_no := reminder_no + 1;
 END LOOP;
 FOR shelf_no IN 1..3 LOOP
 RAISE NOTICE 'Library shelf number: %', shelf_no;
 END LOOP;
END $$;

CREATE OR REPLACE PROCEDURE borrow_book(
 p_book_id INT, p_student_number VARCHAR, p_quantity INT)
LANGUAGE plpgsql
AS $$
DECLARE
 v_available INT;
BEGIN
 IF p_quantity IS NULL OR p_quantity <= 0 THEN
 RAISE EXCEPTION 'Invalid quantity: % (must be greater than zero)', p_quantity
 USING ERRCODE = '22023';
 END IF;
 SELECT available_copies INTO v_available
 FROM books WHERE book_id = p_book_id FOR UPDATE;
 IF NOT FOUND THEN
 RAISE EXCEPTION 'Book % does not exist', p_book_id;
 END IF;
 IF v_available < p_quantity THEN
 RAISE EXCEPTION 'Only % copies available, % requested', v_available, p_quantity;
 END IF;
 UPDATE books SET available_copies = available_copies - p_quantity
 WHERE book_id = p_book_id;
 INSERT INTO book_loans (book_id, student_number, quantity)
 VALUES (p_book_id, p_student_number, p_quantity);
 RAISE NOTICE 'Loan recorded: student % borrowed % copy(ies) of book %',
 p_student_number, p_quantity, p_book_id;
END $$;

DO $$
BEGIN
 CALL borrow_book(1, 'S1001', 2); -- valid
 CALL borrow_book(2, 'S1002', 1); -- valid
 BEGIN
 CALL borrow_book(2, 'S1003', 5); -- exceeds available copies
 EXCEPTION WHEN OTHERS THEN
 RAISE NOTICE 'Loan rejected: %', SQLERRM;
 END;
END $$;
SELECT * FROM books ORDER BY book_id;
SELECT * FROM book_loans ORDER BY loan_id;


CREATE OR REPLACE PROCEDURE return_book(p_loan_id INT)
LANGUAGE plpgsql
AS $$
DECLARE
 v_book_id INT;
 v_qty INT;
BEGIN
 -- Only an ACTIVE loan can be marked returned
 UPDATE book_loans SET loan_status = 'RETURNED'
 WHERE loan_id = p_loan_id AND loan_status = 'ACTIVE'
 RETURNING book_id, quantity INTO v_book_id, v_qty;
 IF NOT FOUND THEN
 RAISE NOTICE 'Loan % is not active or does not exist - no copies restored', p_loan_id;
 ELSE
 UPDATE books SET available_copies = available_copies + v_qty
 WHERE book_id = v_book_id;
 RAISE NOTICE 'Loan % returned - % copy(ies) restored', p_loan_id, v_qty;
 END IF;
END $$;

CALL return_book(1); -- restores copies
CALL return_book(1); -- second call: nothing restored

SELECT * FROM books ORDER BY book_id;
SELECT * FROM book_loans ORDER BY loan_id;

DO $$
DECLARE
 cur_low CURSOR FOR
 SELECT book_id, title, available_copies
 FROM books WHERE available_copies <= 2 ORDER BY available_copies;
 rec RECORD;
BEGIN
 OPEN cur_low;
 LOOP
 FETCH cur_low INTO rec;
 EXIT WHEN NOT FOUND;
 RAISE NOTICE 'Few copies left: % (id %) - % copy(ies)',
 rec.title, rec.book_id, rec.available_copies;
 END LOOP;
 CLOSE cur_low;
END $$;

DO $$
BEGIN
 CALL borrow_book(1, 'S1004', 0);
EXCEPTION
 WHEN invalid_parameter_value THEN
 RAISE NOTICE 'Handled invalid quantity: %', SQLERRM;
END $$;

SELECT book_id, title, available_copies FROM books ORDER BY book_id;
SELECT loan_id, book_id, student_number, quantity, loan_status
FROM book_loans ORDER BY loan_id;



