#!/bin/bash
# Uses plain "mysql" when run as root, "sudo mysql" otherwise
M="mysql"; [ "$(id -u)" -ne 0 ] && M="sudo mysql"
DB="$M -t dems -e"
esc(){ local s="${1//\\/\\\\}"; echo "${s//\'/\\\'}"; }
pause(){ read -rp $'\nPress Enter to continue...' _; }

while true; do
clear
cat <<MENU
=====================================================
     DIGITAL EVIDENCE MANAGEMENT SYSTEM (DEMS)
=====================================================
 1) Dashboard
 2) List all evidence
 3) Search evidence (keyword)
 4) Filter evidence (type / status / case)
 5) Register new case
 6) Register new evidence
 7) Transfer / handle evidence (Chain of Custody)
 8) View chain of custody for an evidence
 9) Case report
10) Add investigator
11) List cases / investigators
 0) Exit
-----------------------------------------------------
MENU
read -rp "Choose: " ch
case $ch in
1) $DB "SELECT (SELECT COUNT(*) FROM cases) AS Cases,
        (SELECT COUNT(*) FROM evidence) AS Evidence,
        (SELECT COUNT(*) FROM chain_of_custody) AS Custody_Entries,
        (SELECT COUNT(*) FROM investigators) AS Investigators;
      SELECT status AS 'Evidence Status', COUNT(*) AS Total FROM evidence GROUP BY status;
      SELECT evidence_type AS 'Evidence Type', COUNT(*) AS Total FROM evidence GROUP BY evidence_type;
      SELECT c.case_id, c.case_title, COUNT(e.evidence_id) AS Evidence_Count
        FROM cases c LEFT JOIN evidence e ON e.case_id=c.case_id GROUP BY c.case_id;
      SELECT * FROM v_custody_history ORDER BY action_datetime DESC LIMIT 5;"; pause;;
2) $DB "SELECT * FROM v_evidence_details ORDER BY evidence_id"; pause;;
3) read -rp "Keyword: " k; k=$(esc "$k")
   $DB "SELECT * FROM v_evidence_details WHERE description LIKE '%$k%' OR file_name LIKE '%$k%'
        OR evidence_type LIKE '%$k%' OR case_title LIKE '%$k%' OR collected_by LIKE '%$k%'
        OR storage_location LIKE '%$k%'"; pause;;
4) echo "Filter by: 1) Type  2) Status  3) Case ID"; read -rp "> " f
   read -rp "Value: " v; v=$(esc "$v")
   case $f in
     1) $DB "SELECT * FROM v_evidence_details WHERE evidence_type='$v'";;
     2) $DB "SELECT * FROM v_evidence_details WHERE status='$v'";;
     3) $DB "SELECT * FROM v_evidence_details WHERE case_id='$v'";;
   esac; pause;;
5) read -rp "Title: " a; read -rp "Type: " b; read -rp "Description: " c
   read -rp "Date (YYYY-MM-DD): " d; read -rp "Lead investigator ID: " e
   $DB "INSERT INTO cases(case_title,case_type,description,registered_date,lead_investigator_id)
        VALUES('$(esc "$a")','$(esc "$b")','$(esc "$c")','$(esc "$d")','$(esc "$e")');
        SELECT LAST_INSERT_ID() AS New_Case_ID;"; pause;;
6) read -rp "Case ID: " a
   echo "Types: Image, Video, Document, Mobile Data, CCTV Footage, Audio, Email, Disk Image, Other"
   read -rp "Type: " b; read -rp "Description: " c; read -rp "File name: " d
   read -rp "Collection date (YYYY-MM-DD): " e; read -rp "Investigator ID: " f
   read -rp "Storage location: " g
   read -rp "Path to file for SHA-256 (blank to skip): " p
   h=""; [ -f "$p" ] && h=$(sha256sum "$p" | cut -d' ' -f1)
   $DB "INSERT INTO evidence(case_id,evidence_type,description,file_name,sha256_hash,collection_date,investigator_id,storage_location)
        VALUES('$(esc "$a")','$(esc "$b")','$(esc "$c")','$(esc "$d")',NULLIF('$h',''),'$(esc "$e")','$(esc "$f")','$(esc "$g")');
        SELECT LAST_INSERT_ID() AS New_Evidence_ID;"; pause;;
7) read -rp "Evidence ID: " a; read -rp "Transferred by (investigator ID): " b
   read -rp "Received by (investigator ID): " c; read -rp "Action (e.g. Sent for Analysis): " d
   read -rp "Remarks: " e; read -rp "New storage location (blank = unchanged): " f
   echo "Status: Collected, In Storage, In Analysis, Transferred, Presented in Court, Returned, Archived"
   read -rp "New status (blank = unchanged): " g
   $DB "CALL transfer_evidence('$(esc "$a")','$(esc "$b")','$(esc "$c")','$(esc "$d")','$(esc "$e")','$(esc "$f")','$(esc "$g")')" && echo "Custody recorded."; pause;;
8) read -rp "Evidence ID: " a
   $DB "SELECT * FROM v_custody_history WHERE evidence_id='$(esc "$a")' ORDER BY action_datetime, custody_id"; pause;;
9) read -rp "Case ID: " a; a=$(esc "$a")
   $DB "SELECT c.*, i.name AS lead FROM cases c JOIN investigators i ON i.investigator_id=c.lead_investigator_id WHERE case_id='$a';
        SELECT * FROM v_evidence_details WHERE case_id='$a';
        SELECT h.* FROM v_custody_history h JOIN evidence e ON e.evidence_id=h.evidence_id WHERE e.case_id='$a' ORDER BY h.action_datetime;"; pause;;
10) read -rp "Name: " a; read -rp "Rank: " b; read -rp "Department: " c; read -rp "Phone: " d; read -rp "Email: " e
   $DB "INSERT INTO investigators(name,rank_title,department,phone,email)
        VALUES('$(esc "$a")','$(esc "$b")','$(esc "$c")','$(esc "$d")','$(esc "$e")'); SELECT LAST_INSERT_ID() AS New_Investigator_ID;"; pause;;
11) $DB "SELECT * FROM cases; SELECT * FROM investigators;"; pause;;
0) exit 0;;
*) echo "Invalid option"; sleep 1;;
esac
done
