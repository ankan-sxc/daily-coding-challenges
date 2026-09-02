CREATE TABLE paysim (
    step INTEGER,
    type VARCHAR(20),
    amount NUMERIC(18,2),
    nameOrig VARCHAR(50),
    oldbalanceOrg NUMERIC(18,2),
    newbalanceOrig NUMERIC(18,2),
    nameDest VARCHAR(50),
    oldbalanceDest NUMERIC(18,2),
    newbalanceDest NUMERIC(18,2),
    isFraud SMALLINT,
    isFlaggedFraud SMALLINT
);

SELECT COUNT(*) FROM paysim;