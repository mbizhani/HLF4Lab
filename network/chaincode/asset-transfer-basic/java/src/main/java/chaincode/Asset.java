package chaincode;

import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import org.hyperledger.fabric.contract.annotation.DataType;
import org.hyperledger.fabric.contract.annotation.Property;

import java.util.Objects;

@Getter
@Setter
@DataType
@NoArgsConstructor
@AllArgsConstructor
public class Asset {
	@Property
	private String assetID;

	@Property
	private String color;

	@Property
	private int size;

	@Property
	private String owner;

	@Property
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

	@Override
	public String toString() {
		return this.getClass().getSimpleName() + "@" + Integer.toHexString(hashCode()) + " [assetID=" + assetID + ", color="
			+ color + ", size=" + size + ", owner=" + owner + ", appraisedValue=" + appraisedValue + "]";
	}
}