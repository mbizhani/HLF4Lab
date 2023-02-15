package org.devocative.hlf.chaincode.model;

import lombok.*;
import org.hyperledger.fabric.contract.annotation.DataType;
import org.hyperledger.fabric.contract.annotation.Property;

import java.util.Objects;

@Getter
@Setter
@ToString
@NoArgsConstructor
@AllArgsConstructor
public class Asset {
	private String assetID;
	private String color;
	private int size;
	private String owner;
	private int appraisedValue;

	// ------------------------------

	@Override
	public boolean equals(final Object obj) {
		if (this == obj) {
			return true;
		}

		if ((obj == null) || (getClass() != obj.getClass())) {
			return false;
		}

		Asset other = (Asset) obj;

		return Objects.deepEquals(
			new String[]{getAssetID(), getColor(), getOwner()},
			new String[]{other.getAssetID(), other.getColor(), other.getOwner()})
			&&
			Objects.deepEquals(
				new int[]{getSize(), getAppraisedValue()},
				new int[]{other.getSize(), other.getAppraisedValue()});
	}

	@Override
	public int hashCode() {
		return Objects.hash(getAssetID(), getColor(), getSize(), getOwner(), getAppraisedValue());
	}
}
