select  a.FollowupBucket , B.* 
from ASM_TRIUMPH_ENQUIRY_DIM a
join ASM_TRIUMPH_Enquiry_FACT b on a.PK_EnquiryHeaderID = b.FK_ENQUIRYDOCID
where EnquiryDate between '2025-06-01' and '2025-06-30'
and DEALERCODE in('0000014129')
and b.LeadType in('Digital','Aggregators') and a.FollowupBucket=