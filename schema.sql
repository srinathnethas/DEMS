DROP DATABASE IF EXISTS dems;
CREATE DATABASE dems;
USE dems;

CREATE TABLE investigators (
  investigator_id INT AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(100) NOT NULL,
  rank_title VARCHAR(50),
  department VARCHAR(100),
  phone VARCHAR(20),
  email VARCHAR(100)
);

CREATE TABLE cases (
  case_id INT AUTO_INCREMENT PRIMARY KEY,
  case_title VARCHAR(150) NOT NULL,
  case_type VARCHAR(50),
  description TEXT,
  status ENUM('Open','Under Investigation','Closed') DEFAULT 'Open',
  registered_date DATE NOT NULL,
  lead_investigator_id INT,
  FOREIGN KEY (lead_investigator_id) REFERENCES investigators(investigator_id)
);

CREATE TABLE evidence (
  evidence_id INT AUTO_INCREMENT PRIMARY KEY,
  case_id INT NOT NULL,
  evidence_type ENUM('Image','Video','Document','Mobile Data','CCTV Footage','Audio','Email','Disk Image','Other') NOT NULL,
  description TEXT,
  file_name VARCHAR(200),
  sha256_hash CHAR(64),
  collection_date DATE NOT NULL,
  investigator_id INT NOT NULL,
  storage_location VARCHAR(150) NOT NULL,
  status ENUM('Collected','In Storage','In Analysis','Transferred','Presented in Court','Returned','Archived') DEFAULT 'Collected',
  FOREIGN KEY (case_id) REFERENCES cases(case_id),
  FOREIGN KEY (investigator_id) REFERENCES investigators(investigator_id),
  INDEX idx_type (evidence_type),
  INDEX idx_status (status)
);

CREATE TABLE chain_of_custody (
  custody_id INT AUTO_INCREMENT PRIMARY KEY,
  evidence_id INT NOT NULL,
  transferred_by INT NOT NULL,
  received_by INT NOT NULL,
  action VARCHAR(100) NOT NULL,
  action_datetime DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  remarks VARCHAR(300),
  FOREIGN KEY (evidence_id) REFERENCES evidence(evidence_id),
  FOREIGN KEY (transferred_by) REFERENCES investigators(investigator_id),
  FOREIGN KEY (received_by) REFERENCES investigators(investigator_id),
  INDEX idx_evid (evidence_id)
);

DELIMITER //

CREATE TRIGGER trg_evidence_collected AFTER INSERT ON evidence
FOR EACH ROW
BEGIN
  INSERT INTO chain_of_custody(evidence_id, transferred_by, received_by, action, remarks)
  VALUES (NEW.evidence_id, NEW.investigator_id, NEW.investigator_id, 'Collected',
          CONCAT('Evidence registered at ', NEW.storage_location));
END//

CREATE TRIGGER trg_custody_no_update BEFORE UPDATE ON chain_of_custody
FOR EACH ROW SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Chain of custody records cannot be modified'//

CREATE TRIGGER trg_custody_no_delete BEFORE DELETE ON chain_of_custody
FOR EACH ROW SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Chain of custody records cannot be deleted'//

CREATE PROCEDURE transfer_evidence(
  IN p_evidence_id INT, IN p_from INT, IN p_to INT,
  IN p_action VARCHAR(100), IN p_remarks VARCHAR(300),
  IN p_new_location VARCHAR(150), IN p_new_status VARCHAR(30))
BEGIN
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN ROLLBACK; RESIGNAL; END;
  START TRANSACTION;
  UPDATE evidence
     SET storage_location = COALESCE(NULLIF(p_new_location,''), storage_location),
         status = COALESCE(NULLIF(p_new_status,''), status)
   WHERE evidence_id = p_evidence_id;
  INSERT INTO chain_of_custody(evidence_id, transferred_by, received_by, action, remarks)
  VALUES (p_evidence_id, p_from, p_to, p_action, p_remarks);
  COMMIT;
END//

DELIMITER ;

CREATE VIEW v_evidence_details AS
SELECT e.evidence_id, e.case_id, c.case_title, e.evidence_type, e.description,
       e.file_name, e.collection_date, i.name AS collected_by,
       e.storage_location, e.status
FROM evidence e
JOIN cases c ON c.case_id = e.case_id
JOIN investigators i ON i.investigator_id = e.investigator_id;

CREATE VIEW v_custody_history AS
SELECT h.custody_id, h.evidence_id, h.action_datetime, h.action,
       f.name AS transferred_by, t.name AS received_by, h.remarks
FROM chain_of_custody h
JOIN investigators f ON f.investigator_id = h.transferred_by
JOIN investigators t ON t.investigator_id = h.received_by;

INSERT INTO investigators(name,rank_title,department,phone,email) VALUES
('Ravi Kumar','Inspector','Cyber Crime','9000000001','ravi@police.example'),
('Anitha Reddy','Sub-Inspector','Forensics','9000000002','anitha@police.example'),
('Suresh Babu','Forensic Analyst','Digital Lab','9000000003','suresh@police.example');

INSERT INTO cases(case_title,case_type,description,status,registered_date,lead_investigator_id) VALUES
('Online Banking Fraud 2026-001','Cyber Crime','Unauthorized transactions via phishing','Under Investigation','2026-09-01',1),
('Warehouse Theft 2026-002','Theft','Theft at port warehouse, CCTV available','Open','2026-09-15',2);

INSERT INTO evidence(case_id,evidence_type,description,file_name,sha256_hash,collection_date,investigator_id,storage_location,status) VALUES
(1,'Mobile Data','Suspect phone extraction','phone_dump.ufdr',SHA2('phone_dump',256),'2026-09-02',1,'Vault A / Shelf 3','In Storage'),
(1,'Email','Phishing emails export','phish_mails.pst',SHA2('phish_mails',256),'2026-09-03',1,'Server /evidence/c1','In Storage'),
(2,'CCTV Footage','Gate camera 22:00-02:00','gate_cam.mp4',SHA2('gate_cam',256),'2026-09-16',2,'Vault B / Drive 7','Collected'),
(2,'Image','Photos of break-in point','breakin_01.jpg',SHA2('breakin_01',256),'2026-09-16',2,'Server /evidence/c2','Collected');

CALL transfer_evidence(1,1,3,'Transferred for Analysis','Sent to digital lab for extraction analysis','Digital Lab Workstation 2','In Analysis');
CALL transfer_evidence(3,2,3,'Transferred for Analysis','Enhancement of CCTV footage requested','Digital Lab Workstation 1','In Analysis');
